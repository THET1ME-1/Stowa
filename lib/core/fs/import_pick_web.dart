import 'dart:async';
import 'dart:io';
import 'dart:js_interop';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import 'web_files.dart' show webFileSystem;
import 'web_fs.dart' show WebFileSystem;

/// Выгрузка для переноса, выбранная окном браузера. Файлы пока лежат у браузера, а перенос
/// читает их с диска, как на телефоне, — поэтому [copy] сперва кладёт их в личную папку сайта.
class BrowserImport {
  BrowserImport._(this._files);

  final List<web.File> _files;
  final _root = '/app/import/${const Uuid().v4()}';

  /// Сколько файлов выбрано.
  int get count => _files.length;

  /// Положить выбранное под `/app/import/<id>/` с путями как в выбранной папке. Возвращает путь
  /// выбранной папки или файла. Крупные файлы уходят из памяти вкладки в хранилище браузера по
  /// мере записи: выгрузка Telegram с фото весит сотни мегабайт.
  Future<String> copy(void Function(int done, int total) progress) async {
    String? top;
    for (var index = 0; index < _files.length; index++) {
      final file = _files[index];
      final relative = file.webkitRelativePath.isEmpty ? file.name : file.webkitRelativePath;
      top ??= relative.split('/').first;
      final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
      final target = File(p.join(_root, relative));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes);
      if (bytes.length > WebFileSystem.lazyFrom) await webFileSystem?.flush();
      progress(index + 1, _files.length);
    }
    await webFileSystem?.flush();
    return p.join(_root, top ?? '');
  }

  /// Стереть скопированное: перенос закончился.
  Future<void> dispose() async {
    final folder = Directory(_root);
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}

/// Окно выбора браузера: папка выгрузки или, при [file], файл закладок. Отменили — null.
/// Служебные папки с точкой (`.obsidian`, `.git`, `.trash`) не берутся: перенос их и так
/// пропускает, а `.git` у хранилища Obsidian бывает тяжелее самих заметок.
Future<BrowserImport?> chooseBrowserImport({required bool file}) {
  final input = web.HTMLInputElement()..type = 'file';
  if (file) {
    input.accept = '.html,.htm';
  } else {
    input.multiple = true;
    input.setAttribute('webkitdirectory', '');
  }
  final done = Completer<BrowserImport?>();
  input.addEventListener(
    'change',
    ((web.Event _) {
      final list = input.files;
      final files = <web.File>[
        if (list != null)
          for (var index = 0; index < list.length; index++)
            if (list.item(index) case final file? when !_hidden(file.webkitRelativePath)) file,
      ];
      if (!done.isCompleted) done.complete(files.isEmpty ? null : BrowserImport._(files));
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!done.isCompleted) done.complete(null);
    }).toJS,
  );
  input.click();
  return done.future;
}

// путь внутри выбранной папки идёт через служебную папку; сама выбранная папка — первая часть
bool _hidden(String relative) => relative.split('/').skip(1).any((part) => part.startsWith('.'));
