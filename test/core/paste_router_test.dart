import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:stowa/core/clipboard/paste_router.dart';

void main() {
  final image = [XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'image.png', mimeType: 'image/png')];

  test('вставку получает место, где работали последним', () async {
    final router = PasteRouter();
    final got = <String>[];
    router.claim('заметка', (files) async => got.add('заметка'));
    router.claim('холст', (files) async => got.add('холст'));
    expect(await router.deliver(image), isTrue);
    // вернулись в заметку — теперь она
    router.claim('заметка', (files) async => got.add('заметка'));
    await router.deliver(image);
    expect(got, ['холст', 'заметка']);
  });

  test('ни одного места — запасное (строка), ушедшее место не получает', () async {
    final router = PasteRouter();
    final got = <String>[];
    router.fallback('строка', (files) async => got.add('строка'));
    router.claim('холст', (files) async => got.add('холст'));
    router.release('холст');
    await router.deliver(image);
    expect(got, ['строка']);
    router.release('строка');
    expect(await router.deliver(image), isFalse);
  });

  test('место не на экране (закрыто другим окном) уступает предыдущему', () async {
    final router = PasteRouter();
    final got = <String>[];
    var noteShown = true;
    router.fallback('строка', (files) async => got.add('строка'));
    router.claim('холст', (files) async => got.add('холст'));
    router.claim('заметка', (files) async => got.add('заметка'), shown: () => noteShown);
    noteShown = false;
    await router.deliver(image);
    expect(got, ['холст']);
  });

  test('пустая вставка никуда не идёт', () async {
    final router = PasteRouter();
    var called = false;
    router.claim('холст', (files) async => called = true);
    expect(await router.deliver(const []), isFalse);
    expect(called, isFalse);
  });
}
