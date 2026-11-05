import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../domain/models.dart';

/// Факт, который извлекатель вернул: ещё без места в базе.
class FactDraft {
  const FactDraft(this.kind, this.value, {this.detail, this.number, this.at});

  final FactKind kind;
  final String value;
  final String? detail;
  final double? number;
  final DateTime? at;
}

/// Вещь глазами извлекателя: сама вещь и её файлы.
class ExtractInput {
  const ExtractInput({required this.item, required this.files, required this.filesRoot});

  final Item item;
  final List<Attachment> files;
  final Directory filesRoot;

  File fileOf(Attachment attachment) => File(p.join(filesRoot.path, attachment.path));

  /// Имя файла, как его прислали: «0_Договор.docx» хранится, «Договор.docx» показывается.
  String nameOf(Attachment attachment) => p.basename(attachment.path).replaceFirst(RegExp(r'^\d+_'), '');
}

/// Маленькое правило без ИИ: достаёт из вещи факты одного вида знания.
///
/// Новый вид знания — новый извлекатель, база не меняется. Улучшили правило —
/// подняли [version], и старые вещи разберутся заново сами.
abstract class Extractor {
  /// Имя в базе. Переименовывать нельзя: старые прогоны потеряются.
  String get name;
  int get version;

  /// Сетевые идут отдельной очередью, только при сети и с отсрочкой после неудачи.
  bool get needsNetwork => false;

  /// SQL-выражение над `items`: от чего зависят факты. Значение сменилось — прогон заново.
  /// Текст зависит от правки, файлы — от набора вложений, страница — от превью.
  String get stampSql;

  /// SQL-условие над `items`: к каким вещам правило вообще относится.
  String get appliesSql => '1';

  Future<List<FactDraft>> extract(ExtractInput input);

  /// Что факты меняют в самой вещи: напоминание события, длина ролика. Идёт после записи фактов.
  /// [firstRun] — правило разбирает вещь впервые: снятое человеком напоминание потом не возвращается.
  Future<void> after(AppDatabase db, Item item, List<FactDraft> facts, {required bool firstRun, required DateTime now}) async {}
}
