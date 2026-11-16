import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/hints_repository.dart';
import 'package:stowa/domain/hints.dart';

import '../../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld()..hints = HintsRepository.memory());
  tearDown(() => world.dispose());

  Future<void> open(WidgetTester tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(world.app());
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  Future<void> stow(WidgetTester tester, String text) async {
    await type(tester, text);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    // плашка «Закинул» уходит сама
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('пустая главная — шаг 1; набор прячет карточку; закинул — шаг 2', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('start-stow')), findsOneWidget);
    expect(find.text('Напиши что угодно и нажми «Закинуть».'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-try')), findsNothing);
    await type(tester, 'Купить молоко');
    expect(find.byKey(const ValueKey('start-stow')), findsNothing);
    await tester.tap(find.text('Закинуть').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-search')), findsOneWidget);
    expect(world.hints.state.stows, 1);
  });

  testWidgets('«Попробовать» в поиске вставляет слово из заметки, найденное засчитывает шаг', (tester) async {
    await open(tester);
    await stow(tester, 'Купить молоко');
    await tester.tap(find.byKey(const ValueKey('start-try')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Купить');
    expect(world.hints.state.done, contains(StartEvent.found));
  });

  testWidgets('«×» пропускает шаг, следующий ждёт новой заметки', (tester) async {
    await open(tester);
    await stow(tester, 'Купить молоко');
    await tester.tap(find.byKey(const ValueKey('start-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-search')), findsNothing);
    await stow(tester, 'Позвонить маме');
    expect(find.byKey(const ValueKey('start-remind')), findsOneWidget);
  });

  testWidgets('напоминание, папка через @, тег и команда засчитываются при сохранении', (tester) async {
    await open(tester);
    await stow(tester, 'Позвонить маме завтра в 10');
    await stow(tester, '#идея приложение');
    await stow(tester, '/задача купить лампу');
    // имя папки после @ бывает с пробелами: сперва «Создать», потом текст
    await type(tester, '@Покупки');
    await tester.tap(find.text('Создать').last);
    await tester.pumpAndSettle();
    await stow(tester, 'хлеб');
    expect(world.hints.state.done, containsAll(StartEvent.values.where((event) => event != StartEvent.found)));
  });

  testWidgets('выключенные подсказки — карточки нет', (tester) async {
    world.hints = HintsRepository.memory(const HintsState(off: true));
    await open(tester);
    expect(find.byKey(const ValueKey('start-stow')), findsNothing);
  });
}
