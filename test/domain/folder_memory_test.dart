import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/folder_guess.dart';

void main() {
  // две книги и бытовая папка: у каждой заметки свой id, как в базе
  List<FolderDoc> library() => const [
    FolderDoc(id: 'a', folderId: 'wireless', text: 'Мальчик с телекинезом проходит тесты способностей'),
    FolderDoc(id: 'b', folderId: 'wireless', text: 'Лаборатория, где изучают детей со способностями. Опыт за стеклом'),
    FolderDoc(id: 'c', folderId: 'novel', text: 'Милтон работает курьером и боится высоты'),
    FolderDoc(id: 'd', folderId: 'novel', text: 'Сцена: Милтон спорит с сестрой из-за денег'),
    FolderDoc(id: 'e', folderId: 'car', text: 'Замена масла и фильтра, мастер сказал прийти через месяц'),
  ];

  const asked = [
    'Мальчик с телекинезом на тестировании способностей поднял все предметы',
    'Пусть у Милтона будет личная проблема, которой он стыдится',
    'поменять масло и фильтр до зимы',
    'ничего общего ни с чем',
  ];

  List<String?> answers(FolderIndex index) => [for (final text in asked) index.guess(text)?.folderId];

  group('память угадывателя', () {
    test('с памятью угадывает то же, что и без неё', () {
      final plain = FolderIndex(library());
      final remembered = FolderIndex(library(), memory: FolderMemory());
      expect(answers(remembered), answers(plain));
      expect(answers(plain), ['wireless', 'novel', 'car', null]);
    });

    test('первая постройка режет на слова каждую заметку', () {
      final memory = FolderMemory();
      FolderIndex(library(), memory: memory);
      expect(memory.parsed, 5);
    });

    test('после правки одной заметки заново режется только она', () {
      final memory = FolderMemory();
      FolderIndex(library(), memory: memory);
      final edited = [
        for (final doc in library())
          doc.id == 'e' ? const FolderDoc(id: 'e', folderId: 'car', text: 'Зимняя резина и шиномонтаж в субботу') : doc,
      ];
      final index = FolderIndex(edited, memory: memory);
      expect(memory.parsed, 6);
      // новый текст виден, старого больше нет
      expect(index.guess('шиномонтаж и резина на зиму')?.folderId, 'car');
      expect(index.guess('поменять масло и фильтр до зимы'), isNull);
    });

    test('заметку переложили в другую папку, текст тот же — слова не режутся, папка новая', () {
      final memory = FolderMemory();
      FolderIndex(library(), memory: memory);
      final moved = [
        for (final doc in library())
          doc.id == 'e' ? FolderDoc(id: 'e', folderId: 'garage', text: doc.text!) : doc,
      ];
      final index = FolderIndex(moved, memory: memory);
      expect(memory.parsed, 5);
      expect(index.guess('поменять масло и фильтр до зимы')?.folderId, 'garage');
    });

    test('удалённую заметку память забывает', () {
      final memory = FolderMemory();
      FolderIndex(library(), memory: memory);
      expect(memory.size, 5);
      FolderIndex(library().where((doc) => doc.id != 'a').toList(), memory: memory);
      expect(memory.size, 4);
    });

    group('отметка правки из базы', () {
      // отметка — что угодно сравнимое: время правки, длина, теги
      List<FolderDoc> stamped() => [for (final doc in library()) FolderDoc(id: doc.id, folderId: doc.folderId, text: doc.text!, stamp: (7, doc.text!.length))];
      List<FolderDoc> remembered() => [for (final doc in library()) FolderDoc.remembered(id: doc.id!, folderId: doc.folderId, stamp: (7, doc.text!.length))];

      test('та же отметка — текст не нужен: угадывает то же и ничего не режет', () {
        final memory = FolderMemory();
        final first = FolderIndex(stamped(), memory: memory);
        expect(memory.parsed, 5);
        final second = FolderIndex(remembered(), memory: memory);
        expect(memory.parsed, 5);
        expect(answers(second), answers(first));
        expect(answers(second), ['wireless', 'novel', 'car', null]);
      });

      test('память отвечает, знает ли заметку с такой отметкой', () {
        final memory = FolderMemory();
        expect(memory.knows('a', (7, 49)), isFalse);
        FolderIndex(stamped(), memory: memory);
        final a = stamped().first;
        expect(memory.knows('a', a.stamp!), isTrue);
        expect(memory.knows('a', (8, a.text!.length)), isFalse, reason: 'правили позже');
        expect(memory.knows('нет такой', a.stamp!), isFalse);
      });

      test('отметка другая — заметка режется заново по новому тексту', () {
        final memory = FolderMemory();
        FolderIndex(stamped(), memory: memory);
        final edited = [
          for (final doc in remembered())
            doc.id == 'e' ? const FolderDoc(id: 'e', folderId: 'car', text: 'Зимняя резина и шиномонтаж в субботу', stamp: (9, 36)) : doc,
        ];
        final index = FolderIndex(edited, memory: memory);
        expect(memory.parsed, 6);
        expect(index.guess('шиномонтаж и резина на зиму')?.folderId, 'car');
        expect(index.guess('поменять масло и фильтр до зимы'), isNull);
      });

      test('текста нет, а память заметку не знает — слов не выдумываем и пустоту не запоминаем', () {
        final memory = FolderMemory();
        final index = FolderIndex(remembered(), memory: memory);
        expect(answers(index), [null, null, null, null]);
        expect(memory.size, 0);
        expect(memory.knows('a', remembered().first.stamp!), isFalse);
        // следующая постройка приносит текст — всё на месте
        expect(answers(FolderIndex(stamped(), memory: memory)), ['wireless', 'novel', 'car', null]);
      });
    });

    test('заметка без id в память не ложится и режется каждый раз', () {
      final memory = FolderMemory();
      const docs = [FolderDoc(folderId: 'car', text: 'Замена масла и фильтра')];
      FolderIndex(docs, memory: memory);
      FolderIndex(docs, memory: memory);
      expect(memory.size, 0);
      expect(memory.parsed, 2);
    });
  });

  group('постройка с передышками', () {
    test('угадывает то же, что обычная', () async {
      final index = await FolderIndex.build(library(), memory: FolderMemory());
      expect(answers(index), answers(FolderIndex(library())));
    });

    test('имена папок и вынутые заметки учитываются так же', () async {
      const labels = [FolderLabel('work', 'Работа'), FolderLabel('home', 'Дом')];
      const rejected = [FolderDoc(folderId: 'work', text: 'отчёт школьный у сына'), FolderDoc(folderId: 'work', text: 'отчёт о поездке')];
      final plain = FolderIndex(const [], labels: labels, rejected: rejected);
      final built = await FolderIndex.build(const [], labels: labels, rejected: rejected);
      for (final text in ['отчёт за квартал', 'совещание на работе в понедельник', 'убраться дома']) {
        expect(built.guess(text)?.folderId, plain.guess(text)?.folderId, reason: text);
      }
    });

    test('большое хранилище не занимает поток целиком: таймер срабатывает до конца постройки', () async {
      // четыреста конспектов по пять тысяч знаков — за один кадр такое не разобрать
      final lecture = List.generate(700, (index) => 'интерференция$index света').join(' ');
      final docs = [for (var index = 0; index < 400; index++) FolderDoc(id: 'n$index', folderId: 'f${index % 7}', text: '$lecture конспект$index')];
      var done = false;
      var breathedBeforeDone = false;
      Timer.run(() => breathedBeforeDone = !done);
      await FolderIndex.build(docs, memory: FolderMemory());
      done = true;
      expect(breathedBeforeDone, isTrue);
    });

    test('маленькое хранилище строится сразу, без таймеров', () async {
      var timerFired = false;
      Timer.run(() => timerFired = true);
      await FolderIndex.build(library(), memory: FolderMemory());
      expect(timerFired, isFalse);
    });
  });

  test('длинная строка без пробелов (ключ, хеш, вставленный мусор) в память слов не ложится', () {
    meaningfulWords('обычное слово');
    final before = folderWordsRemembered;
    final words = meaningfulWords('${'x' * 50000} ${'ключ' * 30}');
    expect(words.map((word) => word.original.length), [50000, 120]);
    expect(folderWordsRemembered, before);
    // а обычное слово помнится
    meaningfulWords('небывалослово');
    expect(folderWordsRemembered, before + 1);
  });

  group('слова заметки', () {
    // «милтон» есть только в книге, и заметок хватает, чтобы слово решало и без веса имени
    final index = FolderIndex(const [
      FolderDoc(folderId: 'novel', text: 'милтон работает курьером'),
      FolderDoc(folderId: 'novel', text: 'милтон спорит с сестрой'),
      FolderDoc(folderId: 'car', text: 'замена масла и фильтра'),
      FolderDoc(folderId: 'home', text: 'купить лампочки в коридор'),
      FolderDoc(folderId: 'trip', text: 'билеты на поезд до Одессы'),
    ]);

    test('заглавное слово после точки, переноса и отступа — начало предложения, не имя', () {
      for (final text in ['Глава первая.\n\n   Милтон', 'Милтон', '  Милтон', 'Сказал: Милтон', 'Вопрос?\tМилтон', '«Милтон']) {
        final guess = index.guess(text);
        expect(guess?.folderId, 'novel', reason: text);
        expect(guess?.byName, isFalse, reason: text);
      }
    });

    test('заглавное слово посреди предложения — имя, сколько бы пробелов перед ним ни стояло', () {
      for (final text in ['и тут вошёл Милтон', 'и тут \t  Милтон', 'вошёл, Милтон', 'тут\nМилтон']) {
        final guess = index.guess(text);
        expect(guess?.folderId, 'novel', reason: text);
        expect(guess?.byName, isTrue, reason: text);
      }
    });

    test('имя остаётся именем на любой глубине длинной заметки', () {
      final filler = List.filled(3000, 'слово').join(' ');
      final guess = index.guess('$filler и тогда Милтон ушёл');
      expect(guess?.folderId, 'novel');
      expect(guess?.byName, isTrue);
    });
  });
}
