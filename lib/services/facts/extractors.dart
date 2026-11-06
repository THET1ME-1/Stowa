import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import '../../domain/contacts.dart';
import '../../domain/document_text.dart';
import '../../domain/image_fingerprint.dart';
import '../../domain/item_kind.dart';
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/photo_facts.dart';
import '../../domain/video_text.dart' show hashtagsIn;
import 'extractor.dart';

/// Местные извлекатели: работают без сети. Сетевые добавляет тот, кто знает, чем ходить в сеть.
List<Extractor> defaultExtractors() => [TextExtractor(), FileTextExtractor(), PhotoExtractor(), FingerprintExtractor(), LinkExtractor()];

const _attachmentsStamp = "coalesce((SELECT group_concat(attachments.id) FROM attachments WHERE attachments.item_id = items.id), '')";

/// Деньги, телефоны, почта и ссылки из заголовка, текста и расшифровки голосового.
class TextExtractor extends Extractor {
  @override
  String get name => 'text';
  @override
  int get version => 1;
  @override
  String get stampSql => "items.updated_at || '|' || coalesce(length(items.transcript), 0)";

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final item = input.item;
    // заголовок обычно повторяет первую строку текста: берём его, только если он свой
    final text = [if (!item.body.startsWith(item.title)) item.title, item.body, ?item.transcript].join('\n');
    final facts = <FactDraft>[];
    for (final money in findMoney(text)) {
      facts.add(FactDraft(FactKind.price, text.substring(money.start, money.end).trim(), detail: money.currency, number: money.amount));
    }
    final seen = <String>{};
    for (final phone in findPhones(text)) {
      if (seen.add(phone.dial)) facts.add(FactDraft(FactKind.phone, phone.text.trim(), detail: phone.dial));
    }
    for (final email in findEmails(text)) {
      if (seen.add(email.address.toLowerCase())) facts.add(FactDraft(FactKind.email, email.address));
    }
    final own = item.url?.toLowerCase();
    for (final link in findLinks(text)) {
      final url = link.url.toLowerCase();
      // адрес самой ссылки и так у вещи, в фактах он лишний
      if (url == own || !seen.add(url)) continue;
      facts.add(FactDraft(FactKind.link, link.url));
    }
    return facts;
  }
}

/// Больше документ не разбираем: телефону хватит и поиска по имени.
const _documentBytesLimit = 50 * 1024 * 1024;

/// Текст документов по листам, слайдам и главам. Разбор — в отдельном потоке.
class FileTextExtractor extends Extractor {
  @override
  String get name => 'file_text';
  @override
  int get version => 1;
  @override
  String get stampSql => _attachmentsStamp;
  @override
  String get appliesSql => 'EXISTS (SELECT 1 FROM attachments WHERE attachments.item_id = items.id)';

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final facts = <FactDraft>[];
    for (final attachment in input.files) {
      final name = input.nameOf(attachment);
      if (!hasDocumentText(name) || attachment.size > _documentBytesLimit) continue;
      final file = input.fileOf(attachment);
      if (!await file.exists()) continue;
      for (final part in await readDocument(file.path, name)) {
        facts.add(FactDraft(FactKind.fileText, part.text, detail: part.place));
      }
    }
    return facts;
  }
}

/// Документ читается в своём потоке: большой DOCX не подвешивает экран.
/// Функция верхнего уровня: замыкание метода потянуло бы в поток весь объект.
Future<List<DocumentPart>> readDocument(String path, String name) => Isolate.run(() => documentText(File(path).readAsBytesSync(), name: name));

/// Дата съёмки, камера, место съёмки из EXIF; скриншот это или фото.
class PhotoExtractor extends Extractor {
  @override
  String get name => 'photo';
  @override
  int get version => 1;
  @override
  String get stampSql => _attachmentsStamp;
  @override
  String get appliesSql => "EXISTS (SELECT 1 FROM attachments WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%')";

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final facts = <FactDraft>[];
    for (final attachment in input.files.where((file) => file.mime.startsWith('image/'))) {
      final file = input.fileOf(attachment);
      if (!await file.exists()) continue;
      final head = await _head(file);
      final photo = photoFactsOf(head);
      if (photo?.takenAt case final taken?) facts.add(FactDraft(FactKind.takenAt, taken.toIso8601String(), at: taken));
      if (photo?.camera case final camera?) facts.add(FactDraft(FactKind.camera, camera));
      if (photo?.latitude case final latitude?) {
        facts.add(FactDraft(FactKind.takenPlace, '$latitude,${photo!.longitude}', number: latitude, detail: '${photo.longitude}'));
      }
      final screenshot = looksLikeScreenshot(fileName: input.nameOf(attachment), mime: attachment.mime, width: attachment.width, height: attachment.height, camera: photo?.camera);
      if (screenshot) facts.add(FactDraft(FactKind.screenshot, input.nameOf(attachment)));
    }
    return facts;
  }

  // EXIF лежит в начале файла: хватает первых 256 КБ
  Future<List<int>> _head(File file) async {
    final reader = await file.open();
    try {
      return await reader.read(256 * 1024);
    } finally {
      await reader.close();
    }
  }
}

/// Отпечаток каждой картинки: по нему страница заметки видит ту же картинку в другой заметке.
/// Картинку сжимает до 9×8 системный декодер, сама картинка в память целиком не разворачивается.
class FingerprintExtractor extends Extractor {
  @override
  String get name => 'fingerprint';
  @override
  int get version => 1;
  @override
  String get stampSql => _attachmentsStamp;
  @override
  String get appliesSql => "EXISTS (SELECT 1 FROM attachments WHERE attachments.item_id = items.id AND attachments.mime LIKE 'image/%')";

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final facts = <FactDraft>[];
    for (final attachment in input.files.where((file) => file.mime.startsWith('image/'))) {
      final file = input.fileOf(attachment);
      if (!await file.exists()) continue;
      try {
        final codec = await ui.instantiateImageCodec(await file.readAsBytes(), targetWidth: 9, targetHeight: 8);
        final frame = await codec.getNextFrame();
        final pixels = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        frame.image.dispose();
        codec.dispose();
        if (pixels != null) facts.add(FactDraft(FactKind.fingerprint, fingerprintText(fingerprintOf(pixels.buffer.asUint8List()))));
      } on Exception {
        // битая или неизвестная декодеру картинка: отпечатка у неё просто нет
      }
    }
    return facts;
  }
}

/// Автор, сайт и описание страницы: превью уже их загрузило, искать по ним можно сразу.
/// Хэштеги из описания (Instagram, TikTok) — предложенные теги.
class LinkExtractor extends Extractor {
  @override
  String get name => 'link';
  @override
  int get version => 2;
  @override
  String get stampSql => "coalesce(items.preview_at, '') || '|' || coalesce(items.url, '')";
  @override
  String get appliesSql => 'items.url IS NOT NULL';

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final item = input.item;
    final host = Uri.tryParse(item.url ?? '')?.host ?? '';
    final site = item.previewSite ?? (host.isEmpty ? null : sourceName(host));
    return [
      if (item.previewAuthor case final author? when author.trim().isNotEmpty) FactDraft(FactKind.author, author.trim()),
      if (site != null && site.trim().isNotEmpty) FactDraft(FactKind.site, site.trim()),
      if (item.previewText case final text? when text.trim().isNotEmpty) FactDraft(FactKind.description, text.trim()),
      for (final tag in hashtagsIn('${item.title}\n${item.previewText ?? ''}')) FactDraft(FactKind.hashtag, tag),
    ];
  }
}
