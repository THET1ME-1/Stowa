import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import 'vault_layout.dart';

/// Файл, положенный на холст-файл (брошен мышью, вставлен из буфера), — вложение холста, как
/// в Obsidian: ложится в папку вложений по настройке хранилища, холст смотрит на него
/// карточкой-файлом. Отдельной заметкой он не становится: читатель хранилища не заводит
/// заметку из файла, на который ссылается холст, — и на главной не появляется.
///
/// Два шага: сперва путь ([pathFor]), холст записывается с карточкой, и только потом сам файл
/// ([write]). Наоборот читатель мог бы застать файл без ссылки и сделать из него заметку.
class CanvasAttachments {
  CanvasAttachments(this._db, {required this.root});

  final AppDatabase _db;

  /// Корень хранилища.
  final Directory root;

  /// Путь от корня для файла [name] холста [canvasPath]: папка вложений, как у заметки на
  /// этом месте, имя свободное — не занятое на диске и вложением или файлом заметки в базе
  /// (короткие ссылки `![[имя]]` Obsidian ищут по всему хранилищу).
  Future<String> pathFor(String canvasPath, String name) async {
    final setting = readAttachmentSetting(root);
    final folder = attachmentFolderFor(canvasPath, obsidian: setting.obsidian, setting: setting.setting);
    final used = {
      for (final row in await _db.select(_db.attachments).get()) p.posix.basename(row.path).toLowerCase(),
      for (final row in await _db.select(_db.vaultFiles).get()) p.posix.basename(row.path).toLowerCase(),
    };
    final wanted = folder.isEmpty ? name : '$folder/$name';
    return uniqueNotePath(wanted, (candidate) => used.contains(p.posix.basename(candidate).toLowerCase()) || File(vaultAbsolute(root.path, candidate)).existsSync());
  }

  /// Записать файл целиком: временный рядом, потом на место — оборванная запись не оставит
  /// половину картинки.
  Future<void> write(String path, Uint8List bytes) async {
    final target = File(vaultAbsolute(root.path, path));
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.stowa-tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }
}
