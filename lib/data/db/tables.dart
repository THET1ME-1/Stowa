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

  /// Где вещь сохранена: координаты и человеческое название места («Ботаника, Кишинёв»).
  /// Пусто — место не разрешено, выключено в настройках или вещь пришла из бота.
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get placeName => text().nullable()();
  DateTimeColumn get reminderAt => dateTime().nullable()();

  /// Напоминание по месту (схема v8): вид и, у точки, координаты с названием.
  /// Срабатывает один раз при входе в круг и снимается, как «Готово».
  TextColumn get remindPlace => textEnum<PlaceReminderKind>().nullable()();
  RealColumn get remindLatitude => real().nullable()();
  RealColumn get remindLongitude => real().nullable()();
  TextColumn get remindPlaceName => text().nullable()();

  /// Своё место из «Мест» (схема v16): его id, когда напоминание у одного места, а не у вида.
  TextColumn get remindPlaceRef => text().nullable()();

  /// День, в который напоминание по месту действует (v16): «завтра буду проходить мимо магазина».
  /// Прошёл — напоминание снимается. Пусто — любой день.
  DateTimeColumn get remindPlaceDay => dateTime().nullable()();

  /// Когда закреплена наверху главной (v18); null — не закреплена. В файле — свойство `pinned`.
  DateTimeColumn get pinnedAt => dateTime().nullable()();

  /// Когда заметку последний раз открывали (v8): «ни разу не открыто» в очереди и сводке.
  /// В файл хранилища не идёт — это след чтения, а не заметка.
  DateTimeColumn get openedAt => dateTime().nullable()();

  /// Ссылка больше не открывается (v10): сайт ответил 404 или 410, либо адреса нет.
  /// [goneKept] — человек решил оставить копию, в «Битых ссылках» её больше нет.
  /// [linkCheckedAt] — когда проверка ссылок ходила по адресу. В файл хранилища не идут.
  DateTimeColumn get goneAt => dateTime().nullable()();
  BoolColumn get goneKept => boolean().withDefault(const Constant(false))();
  DateTimeColumn get linkCheckedAt => dateTime().nullable()();

  /// Где остановился в читалке: доля прокрутки от 0 до 1. Тоже след чтения, не заметка.
  RealColumn get readPosition => real().nullable()();

  /// Свойства из файла заметки, которых Stowa не знает (aliases, rating…), одной картой
  /// в JSON: возвращаются в файл как были. Свойств нет — null.
  TextColumn get properties => text().nullable()();

  /// Текст фактов одной строкой: его индексирует поиск. Пишет `FactsPipeline`.
  TextColumn get factsText => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Цитата из статьи (v10): выделенный кусок текста и пометка к нему. Это написал
/// человек, поэтому цитаты лежат в файле заметки свойством `highlights`.
class Highlights extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();

  /// Сам выделенный текст: по нему цитата находится в статье, даже если разбор улучшат.
  TextColumn get quote => text()();
  TextColumn get note => text().nullable()();

  /// Где цитата в тексте статьи, знаков от начала: порядок в списке.
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Снимок заметки (v12): заголовок и текст, какими были до правки после перерыва.
/// Пишет триггер `items_history`, хранятся 50 последних или все за 30 дней.
/// Умная папка (v13): сохранённый запрос поиска, а не список заметок. Открылась —
/// запрос разбирается заново на сегодня, поэтому «за неделю» — всегда последняя неделя.
class SmartFolders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get query => text()();

  /// Имя иконки Material Symbols.
  TextColumn get icon => text().withDefault(const Constant('manage_search'))();

  /// Цвет из FolderPalette; без выбора — по месту в списке.
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Правило по фактам уже сработало для заметки (v13): что человек потом поменял руками,
/// правило не вернёт. Только в базе: после переустановки разбор и так не повторяется.
class RuleHits extends Table {
  TextColumn get itemId => text()();
  TextColumn get ruleId => text()();

  @override
  Set<Column> get primaryKey => {itemId, ruleId};
}

class NoteVersions extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();

  /// Когда заметка была такой: время её прошлой правки.
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Что извлекатель узнал о вещи: сумма, телефон, текст документа, дата съёмки.
/// Факты одного извлекателя заменяются целиком при каждом его прогоне.
class Facts extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get extractor => text()();
  TextColumn get kind => textEnum<FactKind>()();

  /// Уточнение: валюта, номер для набора, лист или слайд документа, долгота места.
  TextColumn get detail => text().nullable()();

  /// Как показать и искать: «35 лей», «+373 69 123 456», текст листа.
  TextColumn get value => text()();

  /// Число для фильтров: сумма, широта места.
  RealColumn get number => real().nullable()();
  DateTimeColumn get at => dateTime().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Какой извлекатель какой версией разобрал вещь и в каком её состоянии.
/// Версия выросла или отпечаток вещи сменился — вещь разбирается заново.
class ExtractorRuns extends Table {
  TextColumn get itemId => text()();
  TextColumn get extractor => text()();
  IntColumn get version => integer()();

  /// Отпечаток того, от чего зависят факты: правка, набор вложений, превью.
  TextColumn get itemStamp => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Сетевому: когда пробовать снова, миллисекунды от 1970 года.
  IntColumn get nextTry => integer().nullable()();
  TextColumn get error => text().nullable()();

  @override
  Set<Column> get primaryKey => {itemId, extractor};
}

/// Файл, который ещё не лёг во вложения: пишется вместе с вещью одной транзакцией,
/// поэтому не теряется, даже если приложение закрыли или телефон выключился.
/// Задачу держит один исполнитель (главное окно, «Поделиться» или фон) до [claimedUntil].
class FileJobs extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  IntColumn get position => integer()();

  /// Откуда брать: полный путь на телефоне.
  TextColumn get source => text()();

  /// Куда класть: путь от папки приложения, как у вложения.
  TextColumn get target => text()();
  TextColumn get mime => text()();
  IntColumn get size => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get claimedBy => text().nullable()();

  /// До какого времени задача занята, миллисекунды от 1970 года.
  IntColumn get claimedUntil => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Что надо перенести из базы в файлы хранилища. Ставят триггеры (схема v7),
/// забирает писатель хранилища: `item:<id>`, `facts:<id>`, `meta:folders` и другие.
class VaultQueue extends Table {
  TextColumn get target => text()();

  /// Растёт с каждой новой просьбой: писатель снимает задачу, только если
  /// за время записи новой просьбы не пришло.
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// До какого времени задача занята, миллисекунды от 1970 года.
  IntColumn get claimedUntil => integer().nullable()();

  @override
  Set<Column> get primaryKey => {target};
}

/// Отмеченные места (v8): сколько угодно, любого вида. Дом и работа узнаются ещё и по своей сети Wi-Fi.
class Places extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<PlaceKind>()();

  /// Свой вид места (v17): «Курсы», «Бассейн» — вид, которого нет среди готовых; тогда [kind] — other.
  TextColumn get label => text().nullable()();

  /// Значок своего вида (v17), имя Material Symbols; пусто — значок готового вида.
  TextColumn get icon => text().nullable()();

  /// «Дом», «Linella на Ботанике» — что человек увидит в уведомлении.
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// Круг срабатывания, метры: у телефонного GPS разброс около 150.
  IntColumn get radius => integer().withDefault(const Constant(150))();

  /// Имя сети Wi-Fi дома или на работе, если его удалось прочитать.
  TextColumn get wifi => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Где лежит файл вещи и каким он был после нашей последней записи или чтения:
/// изменилось время или размер — файл правили снаружи.
class VaultFiles extends Table {
  TextColumn get itemId => text()();

  /// Путь `.md` от корня хранилища.
  TextColumn get path => text()();

  /// Время изменения файла, миллисекунды от 1970 года.
  IntColumn get modified => integer()();
  IntColumn get size => integer()();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// Флаги хранилища. `importing` — читатель забирает файлы в базу, и триггеры
/// не ставят забранное обратно в очередь записи.
class VaultFlags extends Table {
  TextColumn get name => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {name};
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

  /// Цвет из FolderPalette; без выбора — по месту в списке.
  TextColumn get color => text().nullable()();

  /// Папка, в которой лежит эта (v11); null — верхняя. Глубина руками до трёх (`FolderTree`).
  TextColumn get parentId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get createdByAi => boolean().withDefault(const Constant(false))();
  TextColumn get view => textEnum<FolderView>().withDefault(Constant(FolderView.auto.name))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Скрытая папка (v14): в базе только пока скрытое открыто, на диске — запечатанной.
  /// Ставится всему поддереву: вложенная в скрытую тоже скрыта.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

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
