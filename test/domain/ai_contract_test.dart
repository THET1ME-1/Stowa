import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/ai_contract.dart';
import 'package:stowa/domain/models.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);
  final context = SortContext(
    item: const ItemForAi(id: 'new', kind: ItemKind.note, text: 'Борщ постный: свёкла, капуста, фасоль'),
    folders: const [FolderForAi(id: 'food', name: 'Еда', topTags: ['рецепт']), FolderForAi(id: 'car', name: 'Машина')],
    tags: const [TagForAi(name: 'рецепт', count: 4)],
    examples: const [CorrectionExample(text: 'Плов с бараниной', folderName: 'Еда')],
    candidates: const [LinkCandidate(id: 'old-borsch', title: 'Борщ бабушки', snippet: 'свёкла, говядина')],
    now: now,
    timeZone: 'Europe/Chisinau',
  );

  String answer(Map<String, Object?> json) => jsonEncode({
    'folder_id': null,
    'new_folder': null,
    'tags': <String>[],
    'new_tags': <Object?>[],
    'title': null,
    'description': 'описание',
    'reminder': null,
    'links': <Object?>[],
    ...json,
  });

  test('нормальный ответ разбирается целиком', () {
    final decision = parseSortDecision(
      answer({
        'folder_id': 'food',
        'tags': ['рецепт'],
        'new_tags': [{'name': 'постное', 'icon': 'eco'}],
        'title': 'Постный борщ',
        'reminder': '2026-11-04T10:00:00',
        'links': [{'id': 'old-borsch', 'reason': 'тоже борщ'}],
      }),
      context,
      isIcon: (icon) => icon == 'eco',
    )!;
    expect(decision.folderId, 'food');
    expect(decision.tagNames, ['рецепт']);
    expect(decision.newTags.single.name, 'постное');
    expect(decision.title, 'Постный борщ');
    expect(decision.description, 'описание');
    expect(decision.reminder, DateTime(2026, 11, 4, 10));
    expect(decision.links.single.id, 'old-borsch');
  });

  test('JSON внутри ```json-ограды и с текстом вокруг тоже разбирается', () {
    final decision = parseSortDecision('Вот ответ:\n```json\n${answer({'folder_id': 'car'})}\n```\nГотово.', context);
    expect(decision?.folderId, 'car');
  });

  test('обрезанный JSON — null', () {
    expect(parseSortDecision('{"folder_id": "food", "tags": ["ре', context), isNull);
    expect(parseSortDecision('не знаю', context), isNull);
  });

  test('выдуманный folderId отбрасывается, остальное сохраняется', () {
    final decision = parseSortDecision(answer({'folder_id': 'no-such', 'tags': ['рецепт']}), context)!;
    expect(decision.folderId, isNull);
    expect(decision.tagNames, ['рецепт']);
  });

  test('связи только на кандидатов, на себя — нет', () {
    final decision = parseSortDecision(
      answer({
        'links': [
          {'id': 'old-borsch', 'reason': 'борщ'},
          {'id': 'new', 'reason': 'сама на себя'},
          {'id': 'chужой', 'reason': 'выдумка'},
        ],
      }),
      context,
    )!;
    expect(decision.links.map((link) => link.id), ['old-borsch']);
  });

  test('теги нормализуются: «#Видео» → «видео», повторы убираются', () {
    final decision = parseSortDecision(answer({'tags': ['#Видео', 'видео ', 'Рецепт', 42]}), context)!;
    expect(decision.tagNames, ['видео', 'рецепт']);
  });

  test('день без часа (модель ставит полночь) звенит в 9 утра, как у разбора строки', () {
    expect(parseSortDecision(answer({'reminder': '2027-06-01T00:00:00'}), context)!.reminder, DateTime(2027, 6, 1, 9));
    expect(parseSortDecision(answer({'reminder': '2027-06-01'}), context)!.reminder, DateTime(2027, 6, 1, 9));
    expect(parseSortDecision(answer({'reminder': '2027-06-01T00:30:00'}), context)!.reminder, DateTime(2027, 6, 1, 0, 30));
  });

  test('напоминание в прошлом отбрасывается', () {
    expect(parseSortDecision(answer({'reminder': '2026-11-01T10:00:00'}), context)!.reminder, isNull);
  });

  test('иконка нового тега не из набора заменяется на label', () {
    final decision = parseSortDecision(answer({'new_tags': [{'name': 'дача', 'icon': 'nonsense_icon'}]}), context, isIcon: (_) => false)!;
    expect(decision.newTags.single.icon, 'label');
  });

  test('текст длиннее 6000 знаков урезается в сообщении, картинка идёт image_url data:', () {
    final big = SortContext(
      item: ItemForAi(id: 'x', kind: ItemKind.image, text: 'а' * 9000, imageBase64Jpeg: 'QUJD'),
      folders: const [],
      tags: const [],
      examples: const [],
      candidates: const [],
      now: now,
      timeZone: 'Europe/Chisinau',
    );
    final messages = buildSortMessages(big);
    final user = messages.last['content'] as List<Object?>;
    final text = (user.first as Map<String, Object?>)['text'] as String;
    expect(text.contains('а' * 6000), isTrue);
    expect(text.contains('а' * 6001), isFalse);
    expect(((user.last as Map<String, Object?>)['image_url'] as Map<String, Object?>)['url'], 'data:image/jpeg;base64,QUJD');
  });

  test('запрос знает папки, примеры и время', () {
    final text = jsonEncode(buildSortMessages(context));
    expect(text, contains('food'));
    expect(text, contains('Плов с бараниной'));
    expect(text, contains('Europe/Chisinau'));
    expect(sortResponseFormat()['type'], 'json_schema');
  });

  test('кластер: папка меньше чем из 3 вещей отбрасывается', () {
    final decision = parseClusterDecision(
      jsonEncode({
        'folders': [
          {'name': 'Рецепты', 'icon': 'restaurant', 'item_ids': ['a', 'b', 'c']},
          {'name': 'Мелочь', 'icon': 'label', 'item_ids': ['d', 'e']},
          {'name': 'Чужое', 'icon': 'label', 'item_ids': ['a', 'x', 'y']},
        ],
      }),
      {'a', 'b', 'c', 'd', 'e'},
    )!;
    expect(decision.folders.map((folder) => folder.name), ['Рецепты']);
  });
}
