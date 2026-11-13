/// Перечисления предметной области. Хранятся в базе по имени, поэтому
/// переименовывать значения нельзя, только дописывать.
library;

enum ItemKind { note, link, video, image, file, voice }

/// Где вещь в разборе.
enum SortState { pending, queued, sorted, failed }

/// Кто положил вещь в папку. Решение человека главнее правил и ИИ.
/// similar — алгоритм на телефоне по словам, которые уже лежат в папке.
enum SortedBy { none, rule, ai, user, similar }

enum FolderView { auto, board, canvas, list }

enum TagIconKind { symbol, emoji, image }

/// pageType, priceAbove, priceBelow — условия по фактам: срабатывают после разбора, а не при сохранении.
enum RuleConditionKind { hasTag, domain, keyword, kind, pageType, priceAbove, priceBelow }

/// remindBefore — напоминание за столько минут до начала события.
enum RuleActionKind { toFolder, addTag, remindBefore }

/// Условие правила смотрит на факты, которые появляются после разбора.
bool isFactCondition(RuleConditionKind kind) => kind == RuleConditionKind.pageType || kind == RuleConditionKind.priceAbove || kind == RuleConditionKind.priceBelow;

/// Откуда у вещи тег.
/// similar — алгоритм на телефоне поставил тег, который есть у похожих вещей.
enum TagSource { user, inline, rule, ai, similar }

/// Что извлекатель узнал о вещи.
/// price — сумма с валютой; phone, email, link — из текста; fileText — текст
/// документа; author, site, description — со страницы ссылки; takenAt, camera,
/// takenPlace — из EXIF фото; screenshot — картинка оказалась скриншотом.
/// Со страницы ссылки (шаг 3): pageType — что это за страница; ingredient, timeNeeded,
/// servings — рецепт; inStock, shop — товар; eventStart, eventEnd, venue, venuePlace,
/// address, openingHours — событие и заведение; published, readingTime — статья;
/// year, rating — фильм и книга; subtitle, chapter, hashtag — ролик.
enum FactKind {
  price,
  phone,
  email,
  link,
  fileText,
  author,
  site,
  description,
  takenAt,
  camera,
  takenPlace,
  screenshot,
  pageType,
  ingredient,
  timeNeeded,
  servings,
  inStock,
  shop,
  eventStart,
  eventEnd,
  venue,
  venuePlace,
  address,
  openingHours,
  published,
  readingTime,
  year,
  rating,
  subtitle,
  chapter,
  hashtag,

  /// Страница сама сказала, что она для взрослых: обложка и описание прячутся, пока человек не разрешит.
  adult,

  /// Отпечаток картинки из 64 бит: по нему видно ту же картинку в другой заметке. В поиск не идёт.
  fingerprint,

  /// Текст статьи из копии страницы: число — слов, уточнение — минут чтения.
  articleText,

  /// Цитата статьи с пометкой — только для поиска: сами цитаты живут в таблице `highlights`.
  highlight,

  /// Главный цвет картинки: значение — семья (`ColorFamily.name`), число — доля площади,
  /// уточнение — средний цвет HEX. Ищется фильтром «синее», а не словом.
  color,

  /// Текст QR-кода на фото; уточнение — вид: url, wifi, text.
  qr,

  /// Кадр своего ролика на шкале: значение — путь кадра, число — секунда.
  frame,

  /// Трек-номер посылки из текста: кнопка «Отследить».
  tracking,

  /// Промокод из текста: касание копирует.
  promoCode,

  /// Пароль из текста; уточнение — имя сети рядом. На кнопке и под найденным — точки.
  password,

  /// Номер карты лояльности из текста, только цифры. Под найденным — последние четыре.
  loyaltyCard,
}

/// similar — связь по общим словам или сайту, её считает телефон; в базе
/// хранится только отклонённая, чтобы больше её не предлагать.
enum LinkSource { manual, ai, similar }

/// Вид отмеченного места в «Местах». Мест одного вида сколько угодно: вторая работа,
/// три любимых кафе. Вид даёт значок и слова, по которым место узнаётся в тексте.
enum PlaceKind { home, work, study, shop, pharmacy, food, sport, guests, other }

/// Где напомнить: в точке (здесь, на карте), у одного своего места ([place], id в `ref`)
/// или у любого места вида — имена те же, что у [PlaceKind]. Старые home, work, shop — тоже виды.
enum PlaceReminderKind { point, place, home, work, study, shop, pharmacy, food, sport, guests, other }

/// Вид места, у любого из которых звенит напоминание; у точки и своего места — null.
PlaceKind? placeKindOf(PlaceReminderKind kind) => PlaceKind.values.asNameMap()[kind.name];

/// Напоминание «у любого места вида».
PlaceReminderKind remindAtKind(PlaceKind kind) => PlaceReminderKind.values.byName(kind.name);

/// Напоминание по месту. Точка несёт координаты и название, своё место — его id в [ref]
/// и имя в [name], вид места берёт все места вида из «Мест».
/// [day] — только в этот день: «завтра буду проходить мимо магазина».
class PlaceReminder {
  const PlaceReminder(this.kind, {this.latitude, this.longitude, this.name, this.ref, this.day});

  final PlaceReminderKind kind;
  final double? latitude;
  final double? longitude;
  final String? name;
  final String? ref;
  final DateTime? day;

  @override
  bool operator ==(Object other) =>
      other is PlaceReminder &&
      other.kind == kind &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.name == name &&
      other.ref == ref &&
      other.day == day;

  @override
  int get hashCode => Object.hash(kind, latitude, longitude, name, ref, day);

  @override
  String toString() => 'PlaceReminder($kind, $latitude, $longitude, $name, $ref, $day)';
}
