import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/domain/edge_settings.dart';
import 'package:stowa/services/edge_channel.dart';

void main() {
  late SettingsRepository settings;
  late FakeEdgeChannel channel;
  late EdgeControl control;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    channel = FakeEdgeChannel();
    control = EdgeControl.over(settings, channel);
  });

  test('включение без права: ведёт к праву и остаётся выключенным', () async {
    channel.canDrawAnswer = false;
    expect(await control.enable(), isFalse);
    expect(channel.calls, ['canDraw', 'askDraw']);
    expect(settings.edge.enabled, isFalse);
  });

  test('включение с правом: настройка включена, служба запущена', () async {
    expect(await control.enable(), isTrue);
    expect(settings.edge.enabled, isTrue);
    expect(channel.calls, ['canDraw', 'start']);
  });

  test('вернулись из настроек системы с правом — включается, без права — нет', () async {
    channel.canDrawAnswer = false;
    await control.enable();
    channel.calls.clear();
    channel.canDrawAnswer = true;
    await control.resumed();
    expect(settings.edge.enabled, isTrue);
    expect(channel.calls, ['canDraw', 'start']);
  });

  test('ушёл за правом и вернулся без него — включатель так и выключен, второй раз не спрашивает', () async {
    channel.canDrawAnswer = false;
    await control.enable();
    await control.resumed();
    expect(settings.edge.enabled, isFalse);
    channel.calls.clear();
    await control.resumed();
    expect(channel.calls, isEmpty);
  });

  test('при каждом открытии приложения включённые корешки поднимаются, если служба умерла', () async {
    await control.enable();
    channel.calls.clear();
    await control.resumed();
    expect(channel.calls, ['canDraw', 'start']);
    // право отозвали в системе — включатель гаснет, служба не зовётся
    channel.canDrawAnswer = false;
    channel.calls.clear();
    await control.resumed();
    expect(settings.edge.enabled, isFalse);
    expect(channel.calls, ['canDraw']);
  });

  test('выключение: настройка выключена, служба уводит корешки', () async {
    await control.enable();
    channel.calls.clear();
    await control.disable();
    expect(settings.edge.enabled, isFalse);
    expect(channel.calls, ['stop']);
  });

  test('правка края и размеров: пишется и сразу применяется, если включено; выключено — только пишется', () async {
    await control.change(settings.edge.copyWith(side: EdgeSide.left));
    expect(settings.edge.side, EdgeSide.left);
    expect(channel.calls, isEmpty);
    await control.enable();
    channel.calls.clear();
    await control.change(settings.edge.copyWith(height: 70));
    expect(settings.edge.height, 70);
    expect(channel.calls, ['apply']);
  });
}
