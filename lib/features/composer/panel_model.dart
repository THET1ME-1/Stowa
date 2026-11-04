import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/folder_guess.dart';
import '../../domain/item_kind.dart';
import '../../domain/line_query.dart';
import '../../domain/models.dart';
import '../../domain/sort_rules.dart';

/// Почему вещь ляжет именно сюда: строка показывает это под «Закинуть».
enum SaveReason { chosen, asIs, tag, word, domain, kind, name, similar, none }

/// Что сделает «Закинуть» прямо сейчас.
class SavePlan {
  const SavePlan({
    required this.kind,
    required this.reason,
    this.folder,
    this.reasonValue,
    this.autoTags = const [],
    this.remindAt,
    this.command,
    this.listCount = 0,
    this.attachments = 0,
    this.onlyMedia = false,
  });

  final ItemKind kind;
  final FolderCard? folder;
  final SaveReason reason;

  /// Слово, тег или домен, по которому сработало правило.
  final String? reasonValue;

  /// Теги, которые поставят правила: пунктиром, касание закрепляет.
  final List<String> autoTags;
  final DateTime? remindAt;
  final LineCommand? command;
  final int listCount;
  final int attachments;

  /// Во вложениях только фото и видео: подпись «3 фото», а не «3 файла».
  final bool onlyMedia;
}

sealed class PanelRow {
  const PanelRow();

  String get key;
}

class SaveRow extends PanelRow {
  const SaveRow(this.plan);

  final SavePlan plan;

  @override
  String get key => 'save';
}

class ResultRow extends PanelRow {
  const ResultRow(this.result, {this.canAppend = false});

  final SearchResult result;

  /// Похожая заметка: «Дописать» положит мысль в неё.
  final bool canAppend;

  @override
  String get key => 'i${result.card.id}';
}

class TagRow extends PanelRow {
  const TagRow(this.tag);

  final TagCard tag;

  @override
  String get key => 't${tag.name}';
}

class NewTagRow extends PanelRow {
  const NewTagRow(this.name);

  final String name;

  @override
  String get key => 'tnew';
}

class FolderRow extends PanelRow {
  const FolderRow(this.folder);

  final FolderCard folder;

  @override
  String get key => 'f${folder.id}';
}

/// Такой папки ещё нет: «Создать папку «Книги»».
class NewFolderRow extends PanelRow {
  const NewFolderRow(this.name);

  /// Как набрано, без собаки.
  final String name;

  @override
  String get key => 'fnew';
}

class CommandRow extends PanelRow {
  const CommandRow(this.command, this.key_);

  final LineCommand command;

  /// Как команда пишется на языке интерфейса.
  final String key_;

  @override
  String get key => 'c${command.name}';
}

enum PanelHeader { none, tags, folders, commands, found, nothingFound, similar, fresh }

class PanelState {
  const PanelState({this.rows = const [], this.pick = 0, this.header = PanelHeader.none, this.count = 0, this.kinds = const [], this.understood = const [], this.plan});

  static const empty = PanelState();

  /// Снизу вверх: нулевая строка у самой кнопки.
  final List<PanelRow> rows;

  /// Какая строка белая: её делает кнопка.
  final int pick;
  final PanelHeader header;
  final int count;

  /// Виды среди найденного: фильтр над панелью.
  final List<ItemKind> kinds;

  /// Что поиск понял из запроса и чем отобрал найденное: «видео», «вчера».
  final List<String> understood;
  final SavePlan? plan;
}

const commandIcons = {
  LineCommand.remind: 'alarm',
  LineCommand.task: 'task_alt',
  LineCommand.list: 'checklist',
  LineCommand.find: 'search',
  LineCommand.inbox: 'inbox',
};

/// Всё, из чего складывается панель над строкой.
class PanelInput {
  const PanelInput({
    required this.text,
    required this.caret,
    required this.commandKeys,
    this.chosenTags = const [],
    this.chosenFolder,
    this.attachmentMimes = const [],
    this.tags = const [],
    this.folders = const [],
    this.rules = const [],
    this.found = const [],
    this.understood = const [],
    this.filter,
    this.remindAt,
    this.folderIndex,
  });

  /// Фразы запроса, которыми поиск отобрал [found]. Пусто — искал просто словами.
  final List<String> understood;

  /// Что уже лежит по папкам: угадыватель без сети.
  final FolderIndex? folderIndex;

  final String text;
  final int caret;

  /// Ключи команд на языке интерфейса первыми, потом на остальных.
  final Map<LineCommand, List<String>> commandKeys;
  final List<String> chosenTags;
  final FolderCard? chosenFolder;
  final List<String> attachmentMimes;
  final List<TagCard> tags;
  final List<FolderCard> folders;
  final List<SortRule> rules;
  final List<SearchResult> found;
  final ItemKind? filter;
  final DateTime? remindAt;
}

/// Что ищет поиск: текст без команды, тегов, папок и ссылок, его слова; чипы — фильтром.
({List<String> words, String free, LineCommand? command, String rest}) queryOf(String text, Map<LineCommand, List<String>> keys) {
  final parsed = parseCommand(text, keys);
  final free = parsed.rest.replaceAll(RegExp(r'(^|\s)[#@][^\s#@]*'), ' ').replaceAll(RegExp(r'https?://\S+'), ' ');
  return (words: searchWords(free), free: free.trim(), command: parsed.command, rest: parsed.rest);
}

SavePlan planSave(PanelInput input, {required LineCommand? command, required String rest}) {
  final url = firstUrl(rest);
  final mimes = input.attachmentMimes;
  final kind = detectKind(text: rest, mime: mimes.isEmpty ? null : mimes.first);
  final onlyMedia = mimes.isNotEmpty && mimes.every((mime) => mime.startsWith('image/') || mime.startsWith('video/'));
  final listCount = command == LineCommand.list ? checklistItems(rest).length : 0;
  FolderCard? folderById(String id) => input.folders.where((folder) => folder.id == id).firstOrNull;

  if (command == LineCommand.inbox) {
    return SavePlan(kind: kind, reason: SaveReason.asIs, command: command, remindAt: input.remindAt, attachments: mimes.length, onlyMedia: onlyMedia);
  }
  final outcome = applyRules(input.rules, text: rest, tags: input.chosenTags, host: url?.host, kind: kind);
  final autoTags = outcome.tags.where((tag) => !input.chosenTags.contains(tag)).toList();
  final chosen = input.chosenFolder;
  final ruleFolder = outcome.folderId == null ? null : folderById(outcome.folderId!);
  final rule = outcome.folderRule;
  // ни выбора, ни правила — угадыватель по словам, которые уже лежат в папках
  final guess = chosen == null && ruleFolder == null ? input.folderIndex?.guess(rest, signals: itemSignals(kind: kind, url: url?.toString())) : null;
  final guessFolder = guess == null ? null : folderById(guess.folderId);
  return SavePlan(
    kind: kind,
    folder: chosen ?? ruleFolder ?? guessFolder,
    reason: chosen != null
        ? SaveReason.chosen
        : ruleFolder != null && rule != null
        ? switch (rule.condition) {
            RuleConditionKind.hasTag => SaveReason.tag,
            RuleConditionKind.keyword => SaveReason.word,
            RuleConditionKind.domain => SaveReason.domain,
            RuleConditionKind.kind => SaveReason.kind,
          }
        : guessFolder != null
        ? (guess!.byName ? SaveReason.name : SaveReason.similar)
        : SaveReason.none,
    reasonValue: chosen != null
        ? null
        : ruleFolder != null
        ? rule?.conditionValue
        : guessFolder != null
        ? (guess!.byName ? guess.words.first : guess.words.take(2).join(', '))
        : null,
    autoTags: autoTags,
    remindAt: input.remindAt,
    command: command,
    listCount: listCount,
    attachments: mimes.length,
    onlyMedia: onlyMedia,
  );
}

/// Панель над строкой: подсказки под курсором или «Закинуть» и то, что уже лежит.
PanelState buildPanel(PanelInput input) {
  final token = caretToken(input.text, input.caret);
  if (token != null) return _completions(input, token);

  final query = queryOf(input.text, input.commandKeys);
  final command = query.command;
  final hasContent = query.rest.trim().isNotEmpty || input.attachmentMimes.isNotEmpty;
  final plan = command == LineCommand.find || !hasContent ? null : planSave(input, command: command, rest: query.rest);

  final kinds = <ItemKind>[];
  for (final result in input.found) {
    if (!kinds.contains(result.card.kind)) kinds.add(result.card.kind);
  }
  final filter = kinds.contains(input.filter) ? input.filter : null;
  final shown = filter == null ? input.found : input.found.where((result) => result.card.kind == filter).toList();

  final rows = <PanelRow>[
    if (plan != null) SaveRow(plan),
    // в любую найденную заметку можно дописать, если в строке новая мысль: человек сам видит, куда
    for (final result in shown) ResultRow(result, canAppend: plan != null && result.card.kind == ItemKind.note),
  ];

  // короткий запрос точно совпал с заголовком — белым становится найденное
  final first = shown.firstOrNull;
  final looking =
      plan == null ||
      (first != null &&
          first.hit.strong &&
          firstUrl(query.rest) == null &&
          input.remindAt == null &&
          input.attachmentMimes.isEmpty &&
          command == null &&
          input.chosenTags.isEmpty &&
          input.chosenFolder == null);
  final pick = shown.isNotEmpty && looking && plan != null ? 1 : 0;

  final PanelHeader header;
  if (plan == null) {
    header = shown.isNotEmpty ? PanelHeader.found : (query.words.isEmpty && input.chosenTags.isEmpty ? PanelHeader.none : PanelHeader.nothingFound);
  } else if (shown.isNotEmpty) {
    header = pick == 1 ? PanelHeader.found : PanelHeader.similar;
  } else {
    header = query.words.isNotEmpty ? PanelHeader.fresh : PanelHeader.none;
  }
  return PanelState(
    rows: rows,
    pick: pick,
    header: header,
    count: shown.length,
    kinds: kinds.length > 1 && input.found.length > 2 ? kinds.take(3).toList() : const [],
    understood: input.understood,
    plan: plan,
  );
}

PanelState _completions(PanelInput input, CaretToken token) {
  final query = token.query;
  final rows = <PanelRow>[];
  switch (token.kind) {
    case CaretKind.command:
      for (final entry in input.commandKeys.entries) {
        final key = entry.value.first;
        if (normalizeQuery(key).startsWith(query)) rows.add(CommandRow(entry.key, key));
      }
    case CaretKind.tag:
      var exact = false;
      for (final tag in input.tags.where((tag) => tag.name.startsWith(query) && !input.chosenTags.contains(tag.name)).take(6)) {
        if (tag.name == query) exact = true;
        rows.add(TagRow(tag));
      }
      if (query.isNotEmpty && !exact && !input.chosenTags.contains(query)) rows.add(NewTagRow(query));
    case CaretKind.folder:
      // по началу всего имени («подарки с» → «Подарки Сане») или любого его слова
      final wanted = query.trimRight();
      bool fits(FolderCard folder) {
        final name = normalizeQuery(folder.name);
        return name.startsWith(wanted) || name.split(' ').any((word) => word.startsWith(wanted));
      }

      for (final folder in input.folders.where(fits).take(6)) {
        rows.add(FolderRow(folder));
      }
      final exact = input.folders.any((folder) => normalizeQuery(folder.name) == wanted);
      final name = input.text.substring(token.start + 1, token.end).trim();
      if (name.isNotEmpty && !exact) rows.add(NewFolderRow(name));
  }
  return PanelState(
    rows: rows,
    header: switch (token.kind) {
      CaretKind.tag => PanelHeader.tags,
      CaretKind.folder => PanelHeader.folders,
      CaretKind.command => PanelHeader.commands,
    },
  );
}
