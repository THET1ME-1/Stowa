import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/theme/folder_palette.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/widget_snapshot.dart';

import '../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  Future<void> note(String id, String title, String body, {String? folder, DateTime? pinned, int minutes = 1, bool deleted = false}) {
    final at = world.now.subtract(Duration(minutes: minutes));
    return world.db.into(world.db.items).insert(
      ItemsCompanion.insert(
        id: id,
        kind: ItemKind.note,
        title: title,
        body: Value(body),
        folderId: Value(folder),
        pinnedAt: Value(pinned),
        deletedAt: Value(deleted ? at : null),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  test('список раскладывается в строки с галочками, заголовок не повторяется строкой', () {
    final snapshot = widgetSnapshot(
      notes: const [WidgetNote(id: 'buy', title: 'Купить', body: 'Купить\n- [ ] молоко\n- [x] хлеб\nпосле работы')],
      locked: false,
    );
    expect(snapshot['locked'], false);
    final note = (snapshot['notes'] as List).single as Map;
    expect(note['title'], 'Купить');
    expect(note['lines'], [
      {'text': 'молоко', 'done': false},
      {'text': 'хлеб', 'done': true},
      {'text': 'после работы'},
    ]);
  });

  test('«Код на вход» включён — в файле ни одной заметки', () {
    final snapshot = widgetSnapshot(notes: const [WidgetNote(id: 'a', title: 'Пароль от Wi‑Fi', body: 'qwerty')], locked: true);
    expect(snapshot['locked'], true);
    expect(snapshot['notes'], isEmpty);
  });

  test('длинная заметка — не больше восьми строк', () {
    final body = List.generate(20, (index) => 'строка $index').join('\n');
    final snapshot = widgetSnapshot(notes: [WidgetNote(id: 'a', title: 'Длинная', body: 'Длинная\n$body')], locked: false);
    expect(((snapshot['notes'] as List).single as Map)['lines'], hasLength(8));
  });

  test('из базы: закреплённые первыми, потом свежие; корзины, скрытых папок и 18+ нет', () async {
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'home', name: 'Дом', icon: 'home', shape: 'squircle', color: const Value('sky')));
    await world.db.into(world.db.folders).insert(FoldersCompanion.insert(id: 'secret', name: 'Личное', icon: 'lock', shape: 'squircle', hidden: const Value(true)));
    await note('old', 'Старая', 'Старая', minutes: 50);
    await note('fresh', 'Свежая', 'Свежая', folder: 'home', minutes: 2);
    await note('pin', 'Закреплённая', 'Закреплённая', minutes: 90, pinned: world.now);
    await note('trash', 'В корзине', 'В корзине', deleted: true);
    await note('hidden', 'Из скрытой', 'Из скрытой', folder: 'secret');
    await note('adult', 'Для взрослых', 'Для взрослых');
    await world.db.into(world.db.facts).insert(FactsCompanion.insert(id: 'f', itemId: 'adult', extractor: 'page', kind: FactKind.adult, value: '1'));

    final notes = await widgetNotes(world.db);
    expect(notes.map((note) => note.id), ['pin', 'fresh', 'old']);
    expect(notes.first.pinned, isTrue);
    expect(notes[1].color, FolderPalette.colors['sky']);
    expect(notes[2].color, isNull);
  });

  test('цвет папки уходит в файл числом ARGB', () {
    const sky = Color(0xFF5FCDF5);
    final snapshot = widgetSnapshot(notes: const [WidgetNote(id: 'a', title: 'А', body: 'А', color: sky)], locked: false);
    expect(((snapshot['notes'] as List).single as Map)['color'], 0xFF5FCDF5);
  });
}
