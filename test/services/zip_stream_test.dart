import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/zip_stream.dart';

void main() {
  /// Собрать архив и отдать его байты и сколько кусков ушло получателю.
  Future<(Uint8List, int)> pack(Future<void> Function(ZipStreamWriter zip) fill) async {
    final out = BytesBuilder(copy: false);
    var chunks = 0;
    final zip = ZipStreamWriter((chunk) {
      out.add(chunk);
      chunks++;
    });
    await fill(zip);
    await zip.close();
    return (out.takeBytes(), chunks);
  }

  test('архив читается обычным распаковщиком: имена по-русски, папки, пустой файл, картинка', () async {
    final note = utf8.encode('# Тарт с малиной\n\nиспечь в субботу\n' * 40);
    final photo = Uint8List.fromList(List.generate(100000, (_) => Random(7).nextInt(256)));
    final (bytes, _) = await pack((zip) async {
      await zip.add('manifest.json', utf8.encode('{"app":"stowa"}'));
      await zip.add('files/Рецепты/Тарт с малиной.md', note, modified: DateTime(2026, 11, 20, 12, 30, 44));
      await zip.add('files/Рецепты/пусто.md', Uint8List(0));
      await zip.add('files/Вложения/фото.jpg', photo);
    });
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((file) => file.name), ['manifest.json', 'files/Рецепты/Тарт с малиной.md', 'files/Рецепты/пусто.md', 'files/Вложения/фото.jpg']);
    expect(archive.findFile('files/Рецепты/Тарт с малиной.md')!.content, note);
    expect(archive.findFile('files/Рецепты/пусто.md')!.content, isEmpty);
    expect(archive.findFile('files/Вложения/фото.jpg')!.content, photo);
    expect(utf8.decode(archive.findFile('manifest.json')!.content), '{"app":"stowa"}');
  });

  test('текст сжимается, а то, что уже сжато, кладётся как есть', () async {
    final text = utf8.encode('конспект лекции по физике, интерференция света\n' * 2000);
    final (packed, _) = await pack((zip) => zip.add('files/Конспект.md', text));
    expect(packed.length, lessThan(text.length ~/ 5));

    final noise = Uint8List.fromList(List.generate(50000, (index) => (index * 7919 + index ~/ 3) % 256));
    final (stored, _) = await pack((zip) => zip.add('files/видео.mp4', noise));
    expect(stored.length, lessThan(noise.length + 300));
    expect(ZipDecoder().decodeBytes(stored).files.single.content, noise);
  });

  test('архив уходит получателю по частям, а не одним куском в конце', () async {
    final (bytes, chunks) = await pack((zip) async {
      for (var index = 0; index < 300; index++) {
        await zip.add('files/Заметка $index.md', utf8.encode('заметка номер $index'));
      }
    });
    expect(chunks, greaterThan(300));
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files, hasLength(300));
    expect(utf8.decode(archive.findFile('files/Заметка 299.md')!.content), 'заметка номер 299');
  });

  test('пустой архив тоже архив', () async {
    final (bytes, _) = await pack((zip) async {});
    expect(ZipDecoder().decodeBytes(bytes).files, isEmpty);
  });

  test('после закрытия добавить нельзя', () async {
    final zip = ZipStreamWriter((_) {});
    await zip.close();
    expect(() => zip.add('a.md', Uint8List(0)), throwsStateError);
  });
}
