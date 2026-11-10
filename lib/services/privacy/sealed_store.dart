import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../vault/vault_layout.dart' show serviceFolder;
import 'seal_crypto.dart';

/// Запечатанный файл в списке: каким блобом лежит и каким был, когда его запечатали.
class SealedEntry {
  const SealedEntry({required this.blob, required this.size, required this.modified});

  final String blob;
  final int size;

  /// Время правки, миллисекунды от 1970 года: по нему и размеру файл узнаётся неизменённым.
  final int modified;
}

/// Список запечатанного: путь в открытой папке → блоб.
class SealedManifest {
  const SealedManifest({required this.generation, required this.files});

  final int generation;
  final Map<String, SealedEntry> files;
}

/// Зашифрованные копии скрытого в `.stowa/sealed/` хранилища: блоб на файл и список.
class SealedStore {
  SealedStore(Directory vault) : dir = Directory(p.join(vault.path, serviceFolder, 'sealed'));

  final Directory dir;

  static final _manifestName = RegExp(r'^manifest-(\d+)\.bin$');

  Future<bool> hasSealed() async => (await _manifests()).isNotEmpty;

  /// Запечатать открытую папку целиком. С [previous] неизменённые файлы остаются своими блобами;
  /// без него (открытое осталось от убитого приложения) запечатывается всё заново.
  /// Новый список полон, поэтому после него лишние блобы и старые списки стираются.
  Future<SealedManifest> seal(Directory open, List<int> publicKey, {SealedManifest? previous}) async {
    await dir.create(recursive: true);
    final files = <String, SealedEntry>{};
    if (await open.exists()) {
      await for (final entity in open.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: open.path).split(p.separator).join('/');
        final stat = await entity.stat();
        final modified = stat.modified.millisecondsSinceEpoch;
        final before = previous?.files[relative];
        if (before != null && before.size == stat.size && before.modified == modified && await _blob(before.blob).exists()) {
          files[relative] = before;
          continue;
        }
        final blob = const Uuid().v4();
        await sealFile(entity, _blob(blob), publicKey, header: {'path': relative, 'modified': modified});
        files[relative] = SealedEntry(blob: blob, size: stat.size, modified: modified);
      }
    }
    final known = await _manifests();
    final generation = [previous?.generation ?? 0, for (final (number, _) in known) number].fold(0, (a, b) => a > b ? a : b) + 1;
    final manifest = SealedManifest(generation: generation, files: files);
    final json = utf8.encode(
      jsonEncode({
        'generation': generation,
        'files': {
          for (final MapEntry(key: path, value: entry) in files.entries) path: {'blob': entry.blob, 'size': entry.size, 'modified': entry.modified},
        },
      }),
    );
    final target = File(p.join(dir.path, 'manifest-$generation.bin'));
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(await sealBytes(json, publicKey), flush: true);
    await temp.rename(target.path);
    await _prune(manifest);
    return manifest;
  }

  /// Открыть новейший список в [open]: файлы встают со своим временем правки.
  /// Запечатанного нет — null. Чужой ключ или подмена — [SealBroken].
  Future<SealedManifest?> unseal(Directory open, SealKeys keys) async {
    final manifest = await readManifest(keys);
    if (manifest == null) return null;
    await open.create(recursive: true);
    for (final MapEntry(key: path, value: entry) in manifest.files.entries) {
      final target = File(p.joinAll([open.path, ...path.split('/')]));
      await target.parent.create(recursive: true);
      await openSealedFile(_blob(entry.blob), target, keys);
      await target.setLastModified(DateTime.fromMillisecondsSinceEpoch(entry.modified));
    }
    await _prune(manifest);
    return manifest;
  }

  /// Новейший список без открытия файлов.
  Future<SealedManifest?> readManifest(SealKeys keys) async {
    final known = await _manifests();
    if (known.isEmpty) return null;
    final (_, file) = known.last;
    final json = jsonDecode(utf8.decode(await openSealedBytes(await file.readAsBytes(), keys))) as Map<String, Object?>;
    final files = (json['files']! as Map).cast<String, Object?>();
    return SealedManifest(
      generation: json['generation']! as int,
      files: {
        for (final MapEntry(key: path, value: raw) in files.entries)
          path: SealedEntry(
            blob: (raw! as Map)['blob']! as String,
            size: (raw as Map)['size']! as int,
            modified: raw['modified']! as int,
          ),
      },
    );
  }

  /// «Забыл код»: запечатанное не открыть, оно стирается целиком.
  Future<void> wipe() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  File _blob(String name) => File(p.join(dir.path, '$name.bin'));

  // списки по возрастанию поколения
  Future<List<(int, File)>> _manifests() async {
    if (!await dir.exists()) return const [];
    final found = <(int, File)>[];
    await for (final entity in dir.list()) {
      final match = _manifestName.firstMatch(p.basename(entity.path));
      if (entity is File && match != null) found.add((int.parse(match.group(1)!), entity));
    }
    return found..sort((a, b) => a.$1.compareTo(b.$1));
  }

  // всё, чего нет в новейшем списке: прежние списки, блобы стёртых и изменённых файлов, обрывки записи
  Future<void> _prune(SealedManifest manifest) async {
    final keep = {'manifest-${manifest.generation}.bin', for (final entry in manifest.files.values) '${entry.blob}.bin'};
    await for (final entity in dir.list()) {
      if (entity is File && !keep.contains(p.basename(entity.path))) await entity.delete();
    }
  }
}
