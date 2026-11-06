import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/return_plan.dart';
import 'package:stowa/l10n/app_language.dart';
import 'package:stowa/services/ai_client.dart';

void main() {
  late SettingsRepository settings;
  late MemoryKeyStore keys;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    keys = MemoryKeyStore();
    settings = SettingsRepository(await SharedPreferences.getInstance(), keys);
  });

  test('по умолчанию OpenRouter, бесплатная модель, ключа нет, разбор не идёт', () {
    final ai = settings.ai;
    expect(ai.baseUrl, defaultAiBaseUrl);
    expect(ai.sortModel, defaultSortModel);
    expect(ai.hasKey, isFalse);
    expect(ai.active, isFalse);
  });

  test('ключ хранится отдельно, в настройках только отметка, что он есть', () async {
    await settings.saveKey('  sk-or-123  ');
    expect(await settings.readKey(), 'sk-or-123');
    expect(keys.value, 'sk-or-123');
    expect(settings.ai.hasKey, isTrue);
    await settings.saveKey('');
    expect(settings.ai.hasKey, isFalse);
    expect(keys.value, isNull);
  });

  test('пауза держится до смены ключа', () async {
    await settings.saveKey('sk-old');
    await settings.pause('401');
    expect(settings.ai.active, isFalse);
    await settings.saveKey('sk-new');
    expect(settings.ai.paused, isFalse);
    expect(settings.ai.active, isTrue);
  });

  test('язык: свой выбор или как в системе', () async {
    expect(settings.language, isNull);
    await settings.setLanguage(AppLanguage.de);
    expect(settings.language, AppLanguage.de);
    await settings.setLanguage(null);
    expect(settings.language, isNull);
  });

  test('возврат: по умолчанию всё включено, вечер в 20:00, тихо с 22 до 8, сводка в воскресенье; правка сохраняется', () async {
    final defaults = settings.returns;
    expect((defaults.watchLater, defaults.onThisDay, defaults.week, defaults.shopping), (true, true, true, true));
    expect((defaults.evening, defaults.quietStart, defaults.quietEnd, defaults.weekDay), (20 * 60, 22 * 60, 8 * 60, DateTime.sunday));
    final changes = <ReturnSettings>[];
    final watching = settings.watchReturns().listen(changes.add);
    addTearDown(watching.cancel);
    await settings.setReturns(const ReturnSettings(watchLater: false, evening: 21 * 60 + 30, weekDay: DateTime.saturday));
    await pumpEventQueue();
    final saved = settings.returns;
    expect((saved.watchLater, saved.onThisDay, saved.evening, saved.weekDay), (false, true, 21 * 60 + 30, DateTime.saturday));
    expect(changes.last, saved);
    expect(settings.returnsAsked, isFalse);
    await settings.setReturnsAsked();
    expect(settings.returnsAsked, isTrue);
  });

  test('изменения приходят потоком', () async {
    final seen = <bool>[];
    final subscription = settings.watchAi().listen((ai) => seen.add(ai.hasKey));
    await Future<void>.delayed(Duration.zero);
    await settings.saveKey('sk');
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(seen, [false, true]);
  });
}
