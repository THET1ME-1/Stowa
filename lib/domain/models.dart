/// Перечисления предметной области. Хранятся в базе по имени, поэтому
/// переименовывать значения нельзя, только дописывать.
library;

enum ItemKind { note, link, video, image, file, voice }

/// Где вещь в разборе.
enum SortState { pending, queued, sorted, failed }

/// Кто положил вещь в папку. Решение человека главнее правил и ИИ.
enum SortedBy { none, rule, ai, user }

enum FolderView { auto, board, canvas, list }

enum TagIconKind { symbol, emoji, image }

enum RuleConditionKind { hasTag, domain, keyword, kind }

enum RuleActionKind { toFolder, addTag }

/// Откуда у вещи тег.
enum TagSource { user, inline, rule, ai }

enum LinkSource { manual, ai }
