import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:stowa/features/composer/picked_files.dart';

void main() {
  test('тип файла узнаётся по расширению: текст, видео, документы', () {
    expect(mimeFor('/cache/notes.md'), 'text/markdown');
    expect(mimeFor('/cache/list.txt'), 'text/plain');
    expect(mimeFor('/cache/clip.mp4'), 'video/mp4');
    expect(mimeFor('/cache/clip.MOV'), 'video/quicktime');
    expect(mimeFor('/cache/scan.pdf'), 'application/pdf');
  });

  test('незнакомый формат всё равно принимается', () {
    expect(mimeFor('/cache/save.qwzx'), 'application/octet-stream');
    expect(mimeFor('/cache/no_extension'), 'application/octet-stream');
  });

  test('подсказка системы выручает, когда расширение молчит', () {
    expect(mimeFor('/cache/1000123', hint: 'image/heic'), 'image/heic');
  });

  test('выбранный файл знает свой размер', () async {
    final folder = await Directory.systemTemp.createTemp('stowa_pick');
    addTearDown(() => folder.delete(recursive: true));
    final file = File(p.join(folder.path, 'a.txt'))..writeAsStringSync('привет');
    final picked = await pickedFrom(file.path);
    expect(picked.mime, 'text/plain');
    expect(picked.size, file.lengthSync());
  });

  test('файл без пути (браузер, перетаскивание) ложится байтами во временную папку под своим именем', () async {
    final cache = await Directory.systemTemp.createTemp('stowa_drop');
    addTearDown(() => cache.delete(recursive: true));
    final dropped = XFile.fromData(utf8.encode('план кухни'), name: 'План кухни.txt', path: '/drop/План кухни.txt', mimeType: 'text/plain');
    final picked = await pickedFromXFile(dropped, cache: cache, hasPath: false);
    expect(p.basename(picked.path), 'План кухни.txt');
    expect(p.isWithin(cache.path, picked.path), isTrue);
    expect(picked.mime, 'text/plain');
    expect(picked.size, utf8.encode('план кухни').length);
    expect(File(picked.path).readAsStringSync(), 'план кухни');
  });

  test('файл с путём на диске берётся как есть', () async {
    final folder = await Directory.systemTemp.createTemp('stowa_drop');
    addTearDown(() => folder.delete(recursive: true));
    final file = File(p.join(folder.path, 'фото.jpg'))..writeAsBytesSync([1, 2, 3]);
    final picked = await pickedFromXFile(XFile(file.path), cache: folder);
    expect(picked.path, file.path);
    expect(picked.mime, 'image/jpeg');
  });
}
