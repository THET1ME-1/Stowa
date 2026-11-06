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

enum RuleConditionKind { hasTag, domain, keyword, kind }

enum RuleActionKind { toFolder, addTag }

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
}

/// similar — связь по общим словам или сайту, её считает телефон; в базе
/// хранится только отклонённая, чтобы больше её не предлагать.
enum LinkSource { manual, ai, similar }
