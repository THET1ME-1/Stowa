import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';
import '../../domain/article_text.dart';
import '../../domain/document_text.dart' show documentTextLimit;
import '../../domain/link_preview.dart' show decodePage;
import '../../domain/models.dart';
import '../../domain/site_sources.dart' show adultSite;
import '../../domain/structured_page.dart';
import '../../domain/video_text.dart';
import '../link_preview_service.dart' show Fetch, Post;
import '../page_cache.dart';
import 'extractor.dart';

/// Слова, по которым находится вид страницы на любом из семи языков: «рецепт» найдёт
/// рецепт, даже если самого слова на странице нет.
const pageTypeWords = {
  PageType.recipe: 'рецепт recipe Rezept receta rețetă przepis',
  PageType.product: 'товар product Produkt producto produs produkt',
  PageType.event: 'событие подія event Veranstaltung evento eveniment wydarzenie',
  PageType.place: 'место місце заведение заклад place Ort lugar loc miejsce',
  PageType.movie: 'фильм фільм movie film Film película',
  PageType.series: 'сериал серіал аниме аніме series anime Serie serie serial',
  PageType.comic: 'манга манхва маньхуа комикс комікс manga manhwa manhua comic Comic cómic komiks',
  PageType.book: 'книга book Buch libro carte książka',
  PageType.video: 'видео відео video Video vídeo wideo',
  PageType.article: 'статья стаття article Artikel artículo articol artykuł',
};

/// Субтитров на ролик больше не храним: двухчасовой подкаст и так найдётся.
const _phraseLimit = 3000;

/// Сумма для показа: «4 500», «19.99».
String formatAmount(double amount) {
  if (amount != amount.roundToDouble()) return amount.toStringAsFixed(2);
  final digits = amount.round().toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(' ');
    grouped.write(digits[index]);
  }
  return grouped.toString();
}

/// Факты разобранной страницы. Функция отдельно от извлекателя — её удобно проверять.
List<FactDraft> pageFacts(StructuredPage page) {
  final facts = <FactDraft>[FactDraft(FactKind.pageType, pageTypeWords[page.type]!, detail: page.type.name)];
  for (final ingredient in page.ingredients) {
    facts.add(FactDraft(FactKind.ingredient, ingredient));
  }
  if (page.time case final time?) facts.add(FactDraft(FactKind.timeNeeded, '${time.inMinutes}', number: time.inMinutes.toDouble()));
  if (page.servings case final servings?) facts.add(FactDraft(FactKind.servings, '$servings', number: servings.toDouble()));
  if (page.price case final price?) {
    facts.add(FactDraft(FactKind.price, [formatAmount(price), ?page.currency].join(' '), number: price, detail: page.currency));
  }
  if (page.inStock case final inStock?) facts.add(FactDraft(FactKind.inStock, inStock ? 'yes' : 'no', number: inStock ? 1 : 0));
  for (final shop in [?page.shop, ?page.brand]) {
    facts.add(FactDraft(FactKind.shop, shop));
  }
  if (page.start case final start?) facts.add(FactDraft(FactKind.eventStart, start.toIso8601String(), at: start));
  if (page.end case final end?) facts.add(FactDraft(FactKind.eventEnd, end.toIso8601String(), at: end));
  if (page.venue case final venue?) facts.add(FactDraft(FactKind.venue, venue));
  if (page.address case final address?) facts.add(FactDraft(FactKind.address, address));
  if (page.latitude case final latitude?) {
    facts.add(FactDraft(FactKind.venuePlace, '$latitude,${page.longitude}', number: latitude, detail: '${page.longitude}'));
  }
  if (page.phone case final phone?) facts.add(FactDraft(FactKind.phone, phone, detail: phone.replaceAll(RegExp(r'[^\d+]'), '')));
  if (page.hours.isNotEmpty) facts.add(FactDraft(FactKind.openingHours, page.hours.join('\n')));
  for (final author in page.authors.take(3)) {
    facts.add(FactDraft(FactKind.author, author));
  }
  if (page.published case final published?) facts.add(FactDraft(FactKind.published, published.toIso8601String(), at: published));
  if (page.readingMinutes case final minutes?) facts.add(FactDraft(FactKind.readingTime, '$minutes', number: minutes.toDouble()));
  if (page.year case final year?) facts.add(FactDraft(FactKind.year, '$year', number: year.toDouble()));
  if (page.rating case final rating?) facts.add(FactDraft(FactKind.rating, '$rating', number: rating));
  for (final chapter in page.chapters) {
    facts.add(FactDraft(FactKind.chapter, chapter.title, number: chapter.seconds.toDouble()));
  }
  // жанры — те же теги автора: «драма», «научная_фантастика»
  for (final genre in page.genres) {
    facts.add(FactDraft(FactKind.hashtag, genre.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_')));
  }
  return facts;
}

/// Напоминание о событии — за час до начала, если человек не ставил своего.
const eventReminderLead = Duration(hours: 1);

/// Что страница говорит о себе: рецепт, товар, событие, заведение, статья, фильм, книга.
/// Читает только копию страницы, поэтому работает без сети: улучшили разбор — старые
/// ссылки перечитаются сами. Копию у старых ссылок скачивает [PageFetchExtractor].
class PageExtractor extends Extractor {
  @override
  String get name => 'page';

  // 2: адрес без повторов города и региона; 3: и без города, повторённого в улице;
  // 4: сериал и манга отдельно от фильма и книги, жанры, страницы 18+; 5: и сайты 18+ по адресу;
  // 6: вещи 18+ — в свою папку
  @override
  int get version => 6;
  @override
  String get stampSql => "coalesce(items.preview_at, '') || '|' || coalesce(items.url, '')";
  @override
  String get appliesSql => _linkItems;

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final html = await readPage(input.filesRoot, input.item.id);
    final url = Uri.tryParse(input.item.url ?? '');
    // для взрослых по словам самой страницы, даже если вида у неё нет, или по сайту:
    // страница за проверкой возраста не сохраняется вовсе
    final adult = (html != null && adultPage(html)) || (url != null && adultSite(url));
    final page = html == null ? null : structuredPage(html);
    return [
      if (page != null) ...pageFacts(page),
      if (adult) const FactDraft(FactKind.adult, '18+'),
    ];
  }

  @override
  Future<void> after(AppDatabase db, Item item, List<FactDraft> facts, {required bool firstRun, required DateTime now}) async {
    if (facts.any((fact) => fact.kind == FactKind.adult)) await _toAdultFolder(db, item);
    final start = facts.where((fact) => fact.kind == FactKind.eventStart).map((fact) => fact.at).nonNulls.firstOrNull;
    // напоминание ставится один раз: снял человек — больше не возвращается
    if (firstRun && start != null && item.reminderAt == null && start.isAfter(now)) {
      final lead = start.subtract(eventReminderLead);
      await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(reminderAt: Value(lead.isAfter(now) ? lead : start)));
    }
  }
}

/// Вещь 18+ — в папку «18+». Уступают ей только догадки (угадыватель, ИИ);
/// разложенное руками и своим правилом остаётся где было. Папку заводит сама,
/// а удалённую человеком заново не заводит.
Future<void> _toAdultFolder(AppDatabase db, Item item) async {
  const guesses = [SortedBy.none, SortedBy.similar, SortedBy.ai];
  if (!guesses.contains(item.sortedBy)) return;
  final existing = await (db.select(db.folders)..where((t) => t.name.equals(adultFolderName))).get();
  if (existing.isNotEmpty && existing.every((folder) => folder.deletedAt != null)) return;
  var folderId = existing.where((folder) => folder.deletedAt == null).firstOrNull?.id;
  if (folderId == null) {
    folderId = const Uuid().v4();
    final count = await db.folders.count().getSingle();
    await db.into(db.folders).insert(
      FoldersCompanion.insert(id: folderId, name: adultFolderName, icon: 'explicit', shape: 'cookie9', sortOrder: Value(count), createdByAi: const Value(true)),
    );
  }
  if (item.folderId == folderId) return;
  await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(
    ItemsCompanion(folderId: Value(folderId), sortedBy: const Value(SortedBy.rule), sortState: const Value(SortState.sorted)),
  );
}

/// Имя папки для вещей 18+: одинаковое на всех языках.
const adultFolderName = '18+';

const _linkItems = "items.url IS NOT NULL AND items.kind IN ('link', 'video')";

/// Текст статьи из копии страницы — для поиска и кнопки «Читать». Ролик читать нечего,
/// поэтому только ссылки. Разбор в отдельном потоке: длинная статья не подвешивает экран.
class ArticleExtractor extends Extractor {
  @override
  String get name => 'article';
  @override
  int get version => 1;
  @override
  String get stampSql => "coalesce(items.preview_at, '') || '|' || coalesce(items.url, '')";
  @override
  String get appliesSql => "items.url IS NOT NULL AND items.kind = 'link'";

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final html = await readPage(input.filesRoot, input.item.id);
    final page = Uri.tryParse(input.item.url ?? '');
    if (html == null || page == null) return const [];
    final found = await Isolate.run(() {
      final article = extractArticle(html, page);
      return article == null ? null : (text: article.plainText, words: article.words, minutes: article.minutes);
    });
    if (found == null) return const [];
    final text = found.text.length > documentTextLimit ? found.text.substring(0, documentTextLimit) : found.text;
    return [FactDraft(FactKind.articleText, text, number: found.words.toDouble(), detail: '${found.minutes}')];
  }
}

/// Копия страницы для старых ссылок, сохранённых до того, как превью стало её хранить.
/// Фактов не даёт: скачал — будит [PageExtractor], и тот разбирает уже без сети.
class PageFetchExtractor extends Extractor {
  PageFetchExtractor({required this.fetch});

  final Fetch fetch;
  final _saved = <String>{};

  @override
  String get name => 'page_fetch';
  @override
  int get version => 1;
  @override
  bool get needsNetwork => true;
  @override
  String get stampSql => "coalesce(items.url, '')";
  @override
  String get appliesSql => _linkItems;

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    if (await pageFile(input.filesRoot, input.item.id).exists()) return const [];
    if (await _page(input, fetch) != null) _saved.add(input.item.id);
    return const [];
  }

  @override
  Future<void> after(AppDatabase db, Item item, List<FactDraft> facts, {required bool firstRun, required DateTime now}) async {
    // копия появилась: разбор страницы считается непройденным и пройдёт при следующем местном проходе
    if (!_saved.remove(item.id)) return;
    await (db.delete(db.extractorRuns)..where((t) => t.itemId.equals(item.id) & t.extractor.isIn(['page', 'article']))).go();
  }
}

// копия страницы, а нет её — скачать и сохранить
Future<String?> _page(ExtractInput input, Fetch fetch) async {
  final cached = await readPage(input.filesRoot, input.item.id);
  if (cached != null) return cached;
  final url = Uri.tryParse(input.item.url ?? '');
  if (url == null || !url.hasScheme) return null;
  final reply = await fetch(url);
  // сайт ответил ошибкой: страница не узнана, но и сеть цела — повторять незачем
  if (!reply.ok) return null;
  final html = decodePage(reply.bytes, reply.contentType);
  await savePage(input.filesRoot, input.item.id, html);
  return html;
}

/// Языки субтитров: выбранный в приложении или язык телефона, потом русский и английский.
List<String> subtitleLanguages(String? chosen) {
  final first = chosen ?? PlatformDispatcher.instance.locale.languageCode;
  return {first, 'ru', 'en'}.toList();
}

const _youtubePlayer ='https://www.youtube.com/youtubei/v1/player?prettyPrint=false';

/// Субтитры, главы и хэштеги роликов YouTube и TikTok. Фразы хранятся со временем:
/// поиск находит фразу, касание открывает ролик с этой секунды.
class SubtitlesExtractor extends Extractor {
  SubtitlesExtractor({required this.fetch, required this.post, required this.languages});

  final Fetch fetch;
  final Post post;

  /// Языки субтитров по порядку: язык приложения, потом русский и английский.
  final List<String> Function() languages;

  @override
  String get name => 'subtitles';
  @override
  int get version => 1;
  @override
  bool get needsNetwork => true;
  @override
  String get stampSql => "coalesce(items.url, '')";
  @override
  String get appliesSql => "items.url IS NOT NULL AND (items.url LIKE '%youtu%' OR items.url LIKE '%tiktok.com%')";

  @override
  Future<List<FactDraft>> extract(ExtractInput input) async {
    final url = Uri.tryParse(input.item.url ?? '');
    if (url == null) return const [];
    final id = youtubeId(url);
    if (id != null) return _youtube(id);
    if (url.host.contains('tiktok.com')) return _tiktok(input);
    return const [];
  }

  Future<List<FactDraft>> _youtube(String id) async {
    final body = jsonEncode({
      'videoId': id,
      'context': {
        'client': {'clientName': 'ANDROID', 'clientVersion': '20.10.38', 'androidSdkVersion': 34, 'hl': languages().first},
      },
    });
    final reply = await post(Uri.parse(_youtubePlayer), body);
    if (!reply.ok) throw HttpException('плеер YouTube ответил ${reply.status}');
    final player = parseYoutubePlayer(jsonDecode(utf8.decode(reply.bytes)) as Map<String, Object?>);
    if (player == null) return const [];
    final track = pickTrack(player.tracks, languages());
    final phrases = track == null ? const <Phrase>[] : parseYoutubeCaptions(await _text(track.url));
    return [
      ..._phrases(phrases, track),
      for (final chapter in player.chapters) FactDraft(FactKind.chapter, chapter.title, number: chapter.seconds.toDouble()),
      for (final tag in player.hashtags) FactDraft(FactKind.hashtag, tag),
      if (player.seconds case final seconds?) FactDraft(FactKind.timeNeeded, '$seconds', number: seconds / 60, detail: 'video'),
    ];
  }

  Future<List<FactDraft>> _tiktok(ExtractInput input) async {
    final html = await _page(input, fetch);
    final video = html == null ? null : parseTiktokPage(html);
    if (video == null) return const [];
    final track = pickTrack(video.tracks, languages());
    final phrases = track == null ? const <Phrase>[] : parseWebVtt(await _text(track.url));
    return [
      ..._phrases(phrases, track),
      for (final tag in video.hashtags) FactDraft(FactKind.hashtag, tag),
      if (video.author case final author?) FactDraft(FactKind.author, author),
      if (video.caption.trim().isNotEmpty && video.caption.trim() != input.item.previewText?.trim()) FactDraft(FactKind.description, video.caption.trim()),
      if (video.seconds case final seconds?) FactDraft(FactKind.timeNeeded, '$seconds', number: seconds / 60, detail: 'video'),
    ];
  }

  List<FactDraft> _phrases(List<Phrase> phrases, CaptionTrack? track) => [
    for (final phrase in phrases.take(_phraseLimit)) FactDraft(FactKind.subtitle, phrase.text, number: phrase.seconds, detail: track?.language),
  ];

  Future<String> _text(String url) async {
    final reply = await fetch(Uri.parse(url));
    if (!reply.ok) throw HttpException('субтитры ответили ${reply.status}');
    return utf8.decode(reply.bytes, allowMalformed: true);
  }

  @override
  Future<void> after(AppDatabase db, Item item, List<FactDraft> facts, {required bool firstRun, required DateTime now}) async {
    // длина ролика, которой не было в превью
    final minutes = facts.where((fact) => fact.kind == FactKind.timeNeeded && fact.detail == 'video').map((fact) => fact.number).nonNulls.firstOrNull;
    if (minutes != null && item.durationSeconds == null) {
      await (db.update(db.items)..where((t) => t.id.equals(item.id))).write(ItemsCompanion(durationSeconds: Value((minutes * 60).round())));
    }
  }
}

class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}
