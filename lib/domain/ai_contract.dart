import 'dart:convert';

import 'models.dart';
import 'tag_name.dart';

/// Сколько текста вещи уходит модели.
const aiTextLimit = 6000;

/// Вещь для модели: текст, адрес, заголовок и описание страницы, картинка.
class ItemForAi {
  const ItemForAi({required this.id, required this.kind, required this.text, this.url, this.pageTitle, this.pageDescription, this.imageBase64Jpeg});

  final String id;
  final ItemKind kind;
  final String text;
  final String? url;
  final String? pageTitle;
  final String? pageDescription;

  /// JPEG не больше 1024 точек по длинной стороне.
  final String? imageBase64Jpeg;
}

class FolderForAi {
  const FolderForAi({required this.id, required this.name, this.topTags = const []});

  final String id;
  final String name;
  final List<String> topTags;
}

class TagForAi {
  const TagForAi({required this.name, required this.count});

  final String name;
  final int count;
}

/// Как хозяин раскладывал сам: начало текста вещи и папка, куда он её переложил.
class CorrectionExample {
  const CorrectionExample({required this.text, required this.folderName});

  final String text;
  final String folderName;
}

/// Вещь, с которой модель может связать новую.
class LinkCandidate {
  const LinkCandidate({required this.id, required this.title, required this.snippet});

  final String id;
  final String title;
  final String snippet;
}

class SortContext {
  const SortContext({required this.item, required this.folders, required this.tags, required this.examples, required this.candidates, required this.now, required this.timeZone});

  final ItemForAi item;
  final List<FolderForAi> folders;
  final List<TagForAi> tags;
  final List<CorrectionExample> examples;
  final List<LinkCandidate> candidates;
  final DateTime now;
  final String timeZone;
}

class NewFolder {
  const NewFolder({required this.name, required this.icon});

  final String name;
  final String icon;
}

class NewTag {
  const NewTag({required this.name, required this.icon});

  final String name;
  final String icon;
}

class ProposedLink {
  const ProposedLink({required this.id, required this.reason});

  final String id;
  final String reason;
}

/// Решение модели после проверки: всё выдуманное уже отброшено.
class SortDecision {
  const SortDecision({
    this.folderId,
    this.newFolder,
    this.tagNames = const [],
    this.newTags = const [],
    this.title,
    this.description = '',
    this.reminder,
    this.links = const [],
  });

  final String? folderId;
  final NewFolder? newFolder;
  final List<String> tagNames;
  final List<NewTag> newTags;
  final String? title;
  final String description;
  final DateTime? reminder;
  final List<ProposedLink> links;
}

class ProposedFolder {
  const ProposedFolder({required this.name, required this.icon, required this.itemIds});

  final String name;
  final String icon;
  final List<String> itemIds;
}

class ClusterDecision {
  const ClusterDecision({required this.folders});

  final List<ProposedFolder> folders;
}

const _sortSystem = '''
Ты раскладываешь заметки в приложении Stowa: человек быстро закидывает мысли, ссылки, фото и файлы, а ты решаешь, куда их положить.
Правила:
- Папку выбирай из списка по id. Новую предлагай, только если ни одна не подходит, а вещь явно начинает новую тему.
- Теги короткие, в нижнем регистре, 1–3 штуки, по возможности из списка тегов.
- description — что это за вещь и весь текст с картинки, если он есть. Оно нужно для поиска.
- title — короткий заголовок, только если у вещи его нет или он из одного адреса.
- reminder — только если в тексте явно названо время. Формат ГГГГ-ММ-ДДTчч:мм:сс по поясу человека.
- links — только на кандидатов из списка, с причиной в два-три слова.
- Иконки — имена Material Symbols, например restaurant, directions_car, book.
Отвечай одним JSON по схеме, без пояснений.''';

String _cut(String text, int limit) => text.length <= limit ? text : text.substring(0, limit);

/// Сообщения для разбора одной вещи.
List<Map<String, Object?>> buildSortMessages(SortContext context) {
  final item = context.item;
  final lines = <String>[
    'Папки:',
    if (context.folders.isEmpty) '(пока нет)',
    for (final folder in context.folders) '- ${folder.id}: ${folder.name}${folder.topTags.isEmpty ? '' : ' (частые теги: ${folder.topTags.join(', ')})'}',
    '',
    'Теги:',
    if (context.tags.isEmpty) '(пока нет)',
    for (final tag in context.tags) '- ${tag.name} (${tag.count})',
    if (context.examples.isNotEmpty) ...['', 'Примеры, как раскладывает хозяин:', for (final example in context.examples) '- «${_cut(example.text, 100)}» → ${example.folderName}'],
    if (context.candidates.isNotEmpty) ...['', 'Кандидаты для связей:', for (final one in context.candidates) '- ${one.id}: ${one.title} — ${_cut(one.snippet, 120)}'],
    '',
    'Вещь (${item.kind.name}):',
    _cut(item.text, aiTextLimit),
    if (item.url != null) 'Адрес: ${item.url}',
    if (item.pageTitle != null) 'Заголовок страницы: ${item.pageTitle}',
    if (item.pageDescription != null) 'Описание страницы: ${item.pageDescription}',
    '',
    'Сейчас: ${context.now.toIso8601String()} ${context.timeZone}',
  ];
  return [
    {'role': 'system', 'content': _sortSystem},
    {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': lines.join('\n')},
        if (item.imageBase64Jpeg != null) {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,${item.imageBase64Jpeg}'}},
      ],
    },
  ];
}

Map<String, Object?> _string({bool nullable = false}) => {'type': nullable ? ['string', 'null'] : 'string'};

Map<String, Object?> _named() => {
  'type': 'object',
  'properties': {'name': _string(), 'icon': _string()},
  'required': ['name', 'icon'],
  'additionalProperties': false,
};

/// Схема ответа для `response_format`: поставщик держит модель в ней сам.
Map<String, Object?> sortResponseFormat() => {
  'type': 'json_schema',
  'json_schema': {
    'name': 'stowa_sort',
    'strict': true,
    'schema': {
      'type': 'object',
      'properties': {
        'folder_id': _string(nullable: true),
        'new_folder': {
          'anyOf': [_named(), {'type': 'null'}],
        },
        'tags': {'type': 'array', 'items': _string()},
        'new_tags': {'type': 'array', 'items': _named()},
        'title': _string(nullable: true),
        'description': _string(),
        'reminder': _string(nullable: true),
        'links': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {'id': _string(), 'reason': _string()},
            'required': ['id', 'reason'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['folder_id', 'new_folder', 'tags', 'new_tags', 'title', 'description', 'reminder', 'links'],
      'additionalProperties': false,
    },
  },
};

/// Первый объект верхнего уровня в ответе: модель бывает обернёт его в ограду или текст.
Map<String, Object?>? _jsonObject(String content) {
  try {
    final whole = jsonDecode(content.trim());
    if (whole is Map<String, Object?>) return whole;
  } catch (_) {
    // ниже поищем объект внутри текста
  }
  final start = content.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  for (var index = start; index < content.length; index++) {
    final char = content[index];
    if (inString) {
      if (char == r'\') {
        index++;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') inString = true;
    if (char == '{') depth++;
    if (char == '}' && --depth == 0) {
      try {
        final found = jsonDecode(content.substring(start, index + 1));
        return found is Map<String, Object?> ? found : null;
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

String? _text(Object? value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

List<String> _tags(Object? value) {
  final names = <String>[];
  for (final raw in value is List ? value : const []) {
    if (raw is! String) continue;
    final name = normalizeTagName(raw);
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }
  return names;
}

/// Ответ модели после проверки. null — ответ не разобрался вовсе. Выдуманную
/// папку, связи не на кандидатов, прошлое время и чужие иконки отбрасываем.
SortDecision? parseSortDecision(String content, SortContext context, {bool Function(String icon)? isIcon}) {
  final json = _jsonObject(content);
  if (json == null) return null;
  String icon(Object? raw) => raw is String && (isIcon?.call(raw) ?? true) ? raw : 'label';
  final folderIds = {for (final folder in context.folders) folder.id};
  final candidateIds = {for (final one in context.candidates) one.id};
  final folderId = _text(json['folder_id']);
  final newFolder = json['new_folder'];
  final reminder = DateTime.tryParse(_text(json['reminder']) ?? '');
  return SortDecision(
    folderId: folderId != null && folderIds.contains(folderId) ? folderId : null,
    newFolder: newFolder is Map<String, Object?> && _text(newFolder['name']) != null ? NewFolder(name: _text(newFolder['name'])!, icon: icon(newFolder['icon'])) : null,
    tagNames: _tags(json['tags']),
    newTags: [
      for (final raw in json['new_tags'] is List ? json['new_tags'] as List : const [])
        if (raw is Map<String, Object?> && _text(raw['name']) != null && normalizeTagName(_text(raw['name'])!).isNotEmpty)
          NewTag(name: normalizeTagName(_text(raw['name'])!), icon: icon(raw['icon'])),
    ],
    title: _text(json['title']),
    description: _text(json['description']) ?? '',
    reminder: reminder != null && reminder.isAfter(context.now) ? reminder : null,
    links: [
      for (final raw in json['links'] is List ? json['links'] as List : const [])
        if (raw is Map<String, Object?> && candidateIds.contains(raw['id']) && raw['id'] != context.item.id) ProposedLink(id: raw['id'] as String, reason: _text(raw['reason']) ?? ''),
    ],
  );
}

const _clusterSystem = '''
В приложении Stowa набралось несколько вещей без папки. Предложи новые папки для групп похожих вещей.
Правила: в папке не меньше трёх вещей, вещь в одной папке, имя папки короткое, иконка — имя Material Symbols.
Не подходящие ни к одной группе вещи не трогай. Отвечай JSON: {"folders":[{"name","icon","item_ids":[]}]}''';

/// Сообщения для предложения новых папок из «Без папки».
List<Map<String, Object?>> buildClusterMessages(List<ItemForAi> unsorted, List<FolderForAi> folders) => [
  {'role': 'system', 'content': _clusterSystem},
  {
    'role': 'user',
    'content': [
      'Уже есть папки: ${folders.isEmpty ? '(нет)' : folders.map((folder) => folder.name).join(', ')}',
      '',
      'Вещи без папки:',
      for (final item in unsorted) '- ${item.id}: ${_cut(item.text, 300)}${item.pageTitle == null ? '' : ' (${item.pageTitle})'}',
    ].join('\n'),
  },
];

/// Предложенные папки. Чужие id и повторы выбрасываются, папка меньше трёх вещей — тоже.
ClusterDecision? parseClusterDecision(String content, Set<String> itemIds) {
  final json = _jsonObject(content);
  if (json == null || json['folders'] is! List) return null;
  final taken = <String>{};
  final folders = <ProposedFolder>[];
  for (final raw in json['folders'] as List) {
    if (raw is! Map<String, Object?>) continue;
    final name = _text(raw['name']);
    final ids = [
      for (final id in raw['item_ids'] is List ? raw['item_ids'] as List : const [])
        if (id is String && itemIds.contains(id) && !taken.contains(id)) id,
    ];
    if (name == null || ids.length < 3) continue;
    taken.addAll(ids);
    folders.add(ProposedFolder(name: name, icon: _text(raw['icon']) ?? 'folder', itemIds: ids));
  }
  return ClusterDecision(folders: folders);
}
