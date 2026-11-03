import 'package:drift/drift.dart';

import '../../domain/models.dart';

/// Вещь — всё, что закинули в строку: заметка, ссылка, фото, файл, голосовое.
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<ItemKind>()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get url => text().nullable()();
  TextColumn get folderId => text().nullable()();
  TextColumn get sortState => textEnum<SortState>().withDefault(Constant(SortState.pending.name))();
  TextColumn get sortedBy => textEnum<SortedBy>().withDefault(Constant(SortedBy.none.name))();

  /// Описание от ИИ: ищется, но не показывается как текст вещи.
  TextColumn get aiDescription => text().nullable()();
  TextColumn get transcript => text().nullable()();

  /// Превью ссылки или ролика: обложка (путь от папки приложения), описание
  /// страницы, имя сайта, автор ролика и длина. Пишет `LinkPreviewService`.
  TextColumn get coverPath => text().nullable()();
  TextColumn get previewText => text().nullable()();
  TextColumn get previewSite => text().nullable()();
  TextColumn get previewAuthor => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  /// Когда превью загружено. Пусто — ещё не пробовали или сеть не ответила.
  DateTimeColumn get previewAt => dateTime().nullable()();
  DateTimeColumn get reminderAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();

  /// Путь от папки приложения: абсолютный протухает после переустановки.
  TextColumn get path => text()();
  TextColumn get mime => text()();
  IntColumn get size => integer()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get thumbPath => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Имя иконки Material Symbols.
  TextColumn get icon => text()();

  /// Имя формы значка (BadgeShape.name).
  TextColumn get shape => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get createdByAi => boolean().withDefault(const Constant(false))();
  TextColumn get view => textEnum<FolderView>().withDefault(Constant(FolderView.auto.name))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();

  /// Нормализованное имя (normalizeTagName), второй тег с тем же именем не заводится.
  TextColumn get name => text().unique()();
  TextColumn get iconKind => textEnum<TagIconKind>().withDefault(Constant(TagIconKind.symbol.name))();
  TextColumn get iconValue => text().withDefault(const Constant('label'))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  IntColumn get pinOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ItemTags extends Table {
  TextColumn get itemId => text()();
  TextColumn get tagId => text()();
  TextColumn get source => textEnum<TagSource>()();

  @override
  Set<Column> get primaryKey => {itemId, tagId};
}

/// Правило сортировки без сети: тег → папка, домен → тег, слово → тег, вид → папка.
class Rules extends Table {
  TextColumn get id => text()();
  TextColumn get conditionKind => textEnum<RuleConditionKind>()();
  TextColumn get conditionValue => text()();
  TextColumn get actionKind => textEnum<RuleActionKind>()();
  TextColumn get actionValue => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Связь между вещами, как в Obsidian. Отклонённая не предлагается снова.
class Links extends Table {
  TextColumn get fromId => text()();
  TextColumn get toId => text()();
  TextColumn get source => textEnum<LinkSource>()();
  TextColumn get reason => text().nullable()();
  BoolColumn get rejected => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {fromId, toId};
}

/// Очередь разбора по ключу ИИ.
class AiJobs extends Table {
  TextColumn get itemId => text()();
  TextColumn get kind => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextTryAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {itemId};
}

class AiLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  TextColumn get itemId => text().nullable()();
  TextColumn get request => text()();
  TextColumn get response => text().nullable()();
  TextColumn get error => text().nullable()();
}

/// Сколько раз слово вело в папку или к тегу: подсказки без сети.
class WordStats extends Table {
  TextColumn get word => text()();
  TextColumn get targetKind => text()();
  TextColumn get targetId => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {word, targetKind, targetId};
}

/// Человек переложил вещь сам: так ИИ учится на исправлениях.
class Corrections extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get fromFolderId => text().nullable()();
  TextColumn get toFolderId => text()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CanvasPositions extends Table {
  TextColumn get folderId => text()();
  TextColumn get itemId => text()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width => real()();

  @override
  Set<Column> get primaryKey => {folderId, itemId};
}
