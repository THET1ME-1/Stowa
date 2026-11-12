// Маршрут по главным экранам. Один на два места: тестовый стенд на ноутбуке
// (test/walk_route_test.dart) и настоящее приложение в симуляторе iPhone (walk_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/app.dart';
import 'package:stowa/features/home/note_timeline.dart';
import 'package:stowa/features/settings/settings_blocks.dart';
import 'package:stowa/l10n/app_localizations.dart';

/// Шаг маршрута: имя снимка и ошибка, если шаг не прошёл.
class WalkStep {
  const WalkStep(this.name, this.error);

  final String name;
  final String? error;
}

/// Проходит экраны с главной и после каждого шага просит снимок.
/// [wait] — как дождаться, пока экран успокоится: на стенде и на телефоне по-разному.
/// [device] — добавить шаги, которым нужен настоящий телефон: клавиатура и окно разрешения.
Future<List<WalkStep>> walkScreens(
  WidgetTester tester, {
  required Future<void> Function(String name) shot,
  required Future<void> Function() wait,
  bool device = false,
}) async {
  final l = L.of(tester.element(find.byType(Scaffold).first));
  final steps = <WalkStep>[];
  final line = find.byType(TextField);

  // с любого экрана на главную, строка пустая и свёрнутая
  Future<void> home() async {
    appNavigator.currentState?.popUntil((route) => route.isFirst);
    await wait();
    if (line.evaluate().length == 1) await tester.enterText(line, '');
    // первое «назад» сворачивает редактор, второе закрывает лоток и убирает фокус
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await wait();
  }

  // [after] — вернуть на место то, что шаг подменил, уже после снимка
  Future<void> step(String name, Future<void> Function() body, {VoidCallback? after}) async {
    final label = '${'${steps.length + 1}'.padLeft(2, '0')}-$name';
    String? error;
    try {
      await body();
      await wait();
      error = tester.takeException()?.toString();
    } catch (caught) {
      error = '$caught';
    }
    // снимок нужен и при ошибке: на нём видно, где маршрут застрял
    await shot(label);
    steps.add(WalkStep(label, error));
    after?.call();
    try {
      await home();
      tester.takeException();
    } catch (_) {}
  }

  Future<void> type(String text) async {
    await tester.enterText(line, text);
    await wait();
  }

  Future<void> stow(String text) async {
    await type(text);
    await tester.tap(find.text(l.actionStow).last);
    await wait();
  }

  Future<void> openNote(String title) async {
    await tester.tap(find.descendant(of: find.byType(NoteTimeline), matching: find.text(title)).first);
    await wait();
  }

  Future<void> openSettings() async {
    await tester.tap(find.byTooltip(l.settingsTitle));
    await wait();
  }

  // строка настроек может лежать ниже края экрана: список прокручивается до неё
  Future<void> openSetting(String title) async {
    await openSettings();
    final row = find.widgetWithText(SettingsRow, title);
    await tester.scrollUntilVisible(row, 240, scrollable: find.byType(Scrollable).first);
    await wait();
    await tester.tap(row);
  }

  const first = 'Купить батарейки для пульта';
  // тег не последним словом: иначе строка предлагает теги, а не «Закинуть»
  const second = '#еда Рецепт борща от бабушки';

  await step('главная-пустая', () async {});
  await step('текст-в-строке', () => type(first));
  await step('закинул', () => stow(first));
  await step('заметка-с-тегом', () => stow(second));
  await step('поиск', () => type('батарейки'));
  await step('страница-заметки', () => openNote(first));
  await step('меню-заметки', () async {
    await openNote(first);
    await tester.tap(find.byTooltip(l.itemMore));
  });
  await step('правка-заметки', () async {
    await openNote(first);
    await tester.tap(find.byTooltip(l.itemEdit));
  });
  await step('на-весь-экран', () async {
    await type('# Поездка\n- [ ] паспорт\n- [ ] переходник для розетки');
    await tester.tap(find.byTooltip(l.fullExpand));
  });
  await step('галерея', () => tester.tap(find.byTooltip(l.composerAttach)));
  await step('каталог', () => tester.tap(find.byTooltip(l.catalogTitle)));
  await step('карта', () => tester.tap(find.byTooltip(l.mapTitle)));
  await step('настройки', openSettings);
  await step('оформление', () => openSetting(l.appearanceTitle));
  await step('разбор-ии', () => openSetting(l.settingsAi));
  await step('возвращать', () => openSetting(l.settingsReturns));
  await step('места', () async {
    await openSetting(l.settingsReturns);
    await wait();
    final row = find.widgetWithText(SettingsRow, l.placesTitle);
    await tester.scrollUntilVisible(row, 240, scrollable: find.byType(Scrollable).last);
    await tester.tap(row);
  });
  await step('хранилище', () => openSetting(l.vaultSection));
  await step('корзина', () => openSetting(l.trashTitle));
  await step('бот-telegram', () => openSetting(l.tgTitle));
  await step('теги-и-правила', () => openSetting(l.settingsTooltip));
  await step('приватность', () async {
    await openSettings();
    await tester.scrollUntilVisible(find.widgetWithText(SettingsRow, l.codeCreateRow), 240, scrollable: find.byType(Scrollable).first);
  });
  await step('битые-ссылки', () => openSetting(l.deadLinksTitle));
  await step('язык', () => openSetting(l.settingsLanguage));

  if (device) {
    // настоящая клавиатура: печатать в неё тест не может, зато видно, как строка встаёт над ней
    await step('клавиатура', after: tester.testTextInput.register, () async {
      tester.testTextInput.unregister();
      await tester.tap(line);
      await wait();
    });
    // последним: система спросит про уведомления, а её окно тест закрыть не может
    await step('напоминание', () => stow('Позвонить мастеру завтра в 10'));
  }
  return steps;
}
