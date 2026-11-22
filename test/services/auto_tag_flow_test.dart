import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/capture_service.dart';

import '../helpers/test_app.dart';

// хозяин 22.11: «Авто разбор тегов в заметке работает? Автовыдача». Сквозная проверка тем
// же путём, что строка главной: сохранение через сервис приложения, тег ставится следом сам
void main() {
  late TestWorld world;
  late ProviderContainer app;

  setUp(() {
    world = TestWorld();
    app = ProviderContainer(overrides: world.overrides);
  });
  tearDown(() async {
    app.dispose();
    await world.dispose();
  });

  Future<Map<String, TagSource>> tagsOf(String id) async {
    final db = world.db;
    final rows = await db.customSelect(
      'SELECT tags.name AS name, item_tags.source AS source FROM item_tags JOIN tags ON tags.id = item_tags.tag_id WHERE item_tags.item_id = ?',
      variables: [Variable.withString(id)],
    ).get();
    return {for (final row in rows) row.read<String>('name'): TagSource.values.byName(row.read<String>('source'))};
  }

  Future<String> save(String text) async {
    final id = await app.read(captureServiceProvider).capture(CaptureInput(text: text));
    // теги соседей идут после сохранения, строка их не ждёт
    for (var round = 0; round < 50; round++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return id;
  }

  test('тег из текста ставится сразу, тег похожих заметок — сам, следом за сохранением', () async {
    // человек пометил две заметки про борщ и завёл несколько посторонних
    final first = await save('Борщ с говядиной, рецепт бабушки #рецепт');
    expect((await tagsOf(first))['рецепт'], TagSource.inline);
    await save('Рецепт борща на скорую руку #рецепт');
    for (final note in ['Купить хлеб', 'Позвонить в банк', 'Забрать посылку', 'Счёт за свет', 'Записаться к врачу', 'Идея для подарка']) {
      await save(note);
    }

    // новая заметка без тега, но про то же: тег приходит сам и помечен как подобранный
    final soup = await save('Постный борщ без мяса');
    expect(await tagsOf(soup), {'рецепт': TagSource.similar});

    // непохожая заметка тега не получает
    final other = await save('Оплатить интернет до пятницы');
    expect(await tagsOf(other), isEmpty);
  });
}
