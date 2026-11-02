import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
}
