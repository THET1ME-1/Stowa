// Живая проверка разбора у настоящего поставщика: тот же запрос, что шлёт очередь.
// Ключ — из окружения, в вывод не попадает.
// AI_KEY=… AI_URL=https://api.anthropic.com/v1 AI_MODEL=claude-opus-5-5 flutter test tool/ai_live_check_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stowa/domain/ai_contract.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/ai_client.dart';

void main() {
  final key = Platform.environment['AI_KEY'];
  final url = Platform.environment['AI_URL'] ?? defaultAiBaseUrl;
  final model = Platform.environment['AI_MODEL'] ?? defaultSortModel;

  test('ключ, список моделей и разбор заметки', () async {
    final client = AiClient(http: http.Client(), baseUrl: url, apiKey: key!);
    await client.check();
    final models = await client.models();
    stdout.writeln('моделей: ${models.length}, есть $model: ${models.any((one) => one.id == model)}');
    final context = SortContext(
      item: const ItemForAi(id: 'n1', kind: ItemKind.note, text: 'Купить молоко, хлеб и яйца по дороге домой'),
      folders: const [FolderForAi(id: 'f1', name: 'Покупки'), FolderForAi(id: 'f2', name: 'Работа')],
      tags: const [],
      examples: const [],
      candidates: const [],
      now: DateTime.now(),
      timeZone: 'Europe/Chisinau',
    );
    final started = DateTime.now();
    final content = await client.chat(model: model, messages: buildSortMessages(context), responseFormat: sortResponseFormat());
    final decision = parseSortDecision(content, context);
    stdout.writeln('ответ за ${DateTime.now().difference(started).inMilliseconds} мс, папка: ${decision?.folderId}');
    expect(decision, isNotNull);
    expect(decision!.folderId, 'f1');
  }, skip: key == null ? 'нет AI_KEY' : null, timeout: const Timeout(Duration(minutes: 3)));
}
