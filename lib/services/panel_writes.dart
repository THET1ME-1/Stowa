import 'dart:io';
import 'dart:typed_data';

import '../data/repositories/documents_repository.dart';
import '../data/repositories/folders_repository.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/smart_folders_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../domain/models.dart';
import 'capture_service.dart';
import 'panel_bridge.dart';

/// Записи строки телефона из боковой панели (STOWA-9). База у панели только на чтение
/// (`panel_db.dart`), поэтому каждое место, где строка пишет, подменено: просьба уходит
/// вкладке мостом, вкладка выполняет её своими службами и отвечает. Вложения и голос
/// едут байтами — файлы панели живут в её памяти и вкладке не видны.

// запись с вложениями везёт байты: ролик через канал браузера — не мгновенно
const _captureWait = Duration(seconds: 60);
const _writeWait = Duration(seconds: 8);

Never _noAnswer(String what) => throw StateError('tab did not answer: $what');

/// Заметка для вкладки: всё, что строка положила в [CaptureInput], и байты вложений.
/// Подпись без текста считается здесь же, на время отправки: функцию в канал не положишь.
Future<Map<String, Object?>> captureInputJson(CaptureInput input, DateTime now) async => {
  'text': input.text,
  'files': [
    for (final file in input.files)
      {'name': file.name ?? file.path.split('/').last, 'mime': file.mime, 'size': file.size, 'seconds': file.seconds, 'bytes': await File(file.path).readAsBytes()},
  ],
  'folder': input.forcedFolderId,
  'tags': input.forcedTagNames,
  'reminder': input.forcedReminder?.toIso8601String(),
  'detectReminder': input.detectReminder,
  'asIs': input.asIs,
  'title': input.title,
  'untitled': input.untitled?.call(now),
  'here': input.here,
  'at': input.at?.toIso8601String(),
  'detectPlace': input.detectPlace,
  'place': switch (input.forcedPlace) {
    null => null,
    final place => {
      'kind': place.kind.name,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'name': place.name,
      'ref': place.ref,
      'day': place.day?.toIso8601String(),
    },
  },
};

/// Заметка из панели во вкладке: байты вложений ложатся файлами через [place], дальше —
/// обычное сохранение.
Future<CaptureInput> captureInputFrom(Map<Object?, Object?> json, Future<String> Function(String name, Uint8List bytes) place) async {
  DateTime? time(Object? value) => value == null ? null : DateTime.parse('$value');
  final untitled = json['untitled'] as String?;
  final placeJson = json['place'] as Map?;
  return CaptureInput(
    text: '${json['text'] ?? ''}',
    files: [
      for (final file in (json['files'] as List?) ?? const [])
        if (file case final Map file)
          PickedFile(
            path: await place('${file['name']}', _bytes(file['bytes'])),
            mime: '${file['mime']}',
            size: (file['size'] as num?)?.toInt() ?? 0,
            seconds: (file['seconds'] as num?)?.toInt(),
            name: file['name'] as String?,
          ),
    ],
    forcedFolderId: json['folder'] as String?,
    forcedTagNames: [for (final tag in (json['tags'] as List?) ?? const []) '$tag'],
    forcedReminder: time(json['reminder']),
    detectReminder: json['detectReminder'] != false,
    asIs: json['asIs'] == true,
    title: json['title'] as String?,
    untitled: untitled == null ? null : (_) => untitled,
    here: json['here'] != false,
    at: time(json['at']),
    detectPlace: json['detectPlace'] != false,
    forcedPlace: placeJson == null
        ? null
        : PlaceReminder(
            PlaceReminderKind.values.byName('${placeJson['kind']}'),
            latitude: (placeJson['latitude'] as num?)?.toDouble(),
            longitude: (placeJson['longitude'] as num?)?.toDouble(),
            name: placeJson['name'] as String?,
            ref: placeJson['ref'] as String?,
            day: time(placeJson['day']),
          ),
  );
}

Uint8List _bytes(Object? value) => switch (value) {
  final Uint8List bytes => bytes,
  final List<Object?> list => Uint8List.fromList([for (final byte in list) (byte as num).toInt()]),
  _ => Uint8List(0),
};

/// Папка, которую вкладка завела по просьбе панели.
Map<String, Object?> folderCardJson(FolderCard card) => {
  'id': card.id,
  'name': card.name,
  'icon': card.icon,
  'shape': card.shape,
  'order': card.order,
  'parentId': card.parentId,
  'path': card.path,
  'hidden': card.hidden,
};

FolderCard folderCardFrom(Map<Object?, Object?> json) => FolderCard(
  id: '${json['id']}',
  name: '${json['name']}',
  icon: '${json['icon']}',
  shape: '${json['shape']}',
  count: 0,
  covers: const [],
  recentTitles: const [],
  createdByAi: false,
  order: (json['order'] as num?)?.toInt() ?? 0,
  parentId: json['parentId'] as String?,
  path: [for (final part in (json['path'] as List?) ?? const []) '$part'],
  hidden: json['hidden'] == true,
);

/// Сохранение строки в панели: заметку сохраняет вкладка.
class PanelCaptureService extends CaptureService {
  PanelCaptureService(super.db, this._client, {required super.filesRoot, super.clock}) : _now = clock ?? DateTime.now, super(tags: TagsRepository(db));

  final PanelClient _client;
  final DateTime Function() _now;

  @override
  Future<List<String>> captureAll(List<CaptureInput> inputs) async {
    final now = _now();
    final answer = await _client.ask('capture-inputs', payload: {'inputs': [for (final input in inputs) await captureInputJson(input, now)]}, timeout: _captureWait);
    if (answer?['type'] != 'captured') _noAnswer('capture');
    return [for (final id in (answer!['items'] as List?) ?? const []) '$id'];
  }

  // файлы уже у вкладки: ей и доводить их до хранилища
  @override
  Future<void> settled() async {}
}

/// «Дописать» и «Отменить» строки в панели — во вкладке.
class PanelItemsRepository extends ItemsRepository {
  PanelItemsRepository(super.db, this._client, {super.clock});

  final PanelClient _client;

  @override
  Future<void> append(String id, String text, DateTime at) async {
    final answer = await _client.ask('append', payload: {'item': id, 'text': text}, timeout: _writeWait);
    if (answer?['type'] != 'appended') _noAnswer('append');
  }

  @override
  Future<void> softDelete(String id, DateTime at) async {
    final answer = await _client.ask('undo', payload: {'item': id}, timeout: _writeWait);
    if (answer?['type'] != 'undone') _noAnswer('undo');
  }
}

/// Новая папка из «@Имя» в панели — во вкладке.
class PanelFoldersRepository extends FoldersRepository {
  PanelFoldersRepository(super.db, this._client);

  final PanelClient _client;

  @override
  Future<FolderCard> create(String rawName, {String? parentId}) async {
    final answer = await _client.ask('folder', payload: {'name': rawName, 'parent': parentId}, timeout: _writeWait);
    if (answer?['card'] case final Map card) return folderCardFrom(card);
    _noAnswer('folder');
  }
}

/// Умная папка из найденного в панели — во вкладке.
class PanelSmartFoldersRepository extends SmartFoldersRepository {
  PanelSmartFoldersRepository(super.db, this._client, {super.clock});

  final PanelClient _client;

  @override
  Future<String> create({required String name, required String query}) async {
    final answer = await _client.ask('smart-folder', payload: {'name': name, 'query': query}, timeout: _writeWait);
    if (answer?['item'] case final String id) return id;
    _noAnswer('smart folder');
  }
}

/// Холст и база командой строки в панели — во вкладке.
class PanelDocumentsRepository extends DocumentsRepository {
  PanelDocumentsRepository(super.db, this._client, {super.clock});

  final PanelClient _client;

  @override
  Future<String> create(ItemKind kind, {required String title, String? folderId}) async {
    final answer = await _client.ask('document', payload: {'kind': kind.name, 'title': title, 'folder': folderId}, timeout: _writeWait);
    if (answer?['item'] case final String id) return id;
    _noAnswer('document');
  }
}

/// Чем вкладка выполняет записи панели: те же службы, что у её строки.
class PanelWrites {
  const PanelWrites({
    required this.captureAll,
    required this.append,
    required this.makeFolder,
    required this.makeSmartFolder,
    required this.makeDocument,
    required this.placeFile,
  });

  final Future<List<String>> Function(List<CaptureInput> inputs) captureAll;
  final Future<void> Function(String id, String text) append;
  final Future<FolderCard> Function(String name, String? parentId) makeFolder;
  final Future<String> Function(String name, String query) makeSmartFolder;
  final Future<String> Function(ItemKind kind, String title, String? folderId) makeDocument;

  /// Положить байты вложения временным файлом вкладки; ответ — путь.
  final Future<String> Function(String name, Uint8List bytes) placeFile;
}

/// Ответить панели на просьбу записи; не своя просьба — false.
Future<bool> answerPanelWrite(PanelWrites writes, Map<String, Object?> message, void Function(String type, [Map<String, Object?> more]) reply) async {
  switch (message['type']) {
    case 'capture-inputs':
      final inputs = [for (final json in (message['inputs'] as List?) ?? const []) await captureInputFrom(json as Map, writes.placeFile)];
      reply('captured', {'items': await writes.captureAll(inputs)});
    case 'append':
      await writes.append('${message['item']}', '${message['text'] ?? ''}');
      reply('appended');
    case 'folder':
      reply('folder-made', {'card': folderCardJson(await writes.makeFolder('${message['name']}', message['parent'] as String?))});
    case 'smart-folder':
      reply('smart-folder-made', {'item': await writes.makeSmartFolder('${message['name']}', '${message['query']}')});
    case 'document':
      reply('document-made', {'item': await writes.makeDocument(ItemKind.values.byName('${message['kind']}'), '${message['title']}', message['folder'] as String?)});
    default:
      return false;
  }
  return true;
}
