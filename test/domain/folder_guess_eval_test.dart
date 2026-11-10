// Проверка раскладки без ИИ на живых заметках семи языков и ещё трёх «чужих».
// Папки пустые: так видно, что раскладка работает с первого дня, по именам и темам.
// null — заметке место в «Без папки»: ошибиться хуже, чем промолчать.
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/folder_guess.dart';

const _folders = [
  'Книга', 'Продукты', 'Рецепты', 'Покупки', 'Кино', 'Музыка', 'Путешествия', 'Работа', 'Учёба', //
  'Здоровье', 'Спорт', 'Ремонт', 'Машина', 'Финансы', 'Дети', 'Питомцы', '18+',
];

const _cases = <(String, String?)>[
  // русский
  ('А что если в финале Мира предаст отряд и уйдёт к злодею', 'Книга'),
  ('Новый персонаж: старый маг, который помнит пророчество', 'Книга'),
  ('Пролог переписать, слишком затянуто', 'Книга'),
  ('молоко, хлеб, яйца', 'Продукты'),
  ('взять творог и кефир на завтрак', 'Продукты'),
  ('Блины: тесто на кефире, жарить на сковороде', 'Рецепты'),
  ('Запечь курицу в духовке 40 минут', 'Рецепты'),
  ('заказать на озоне чехол для телефона', 'Покупки'),
  ('Посмотреть сериал Тёмный, третий сезон', 'Кино'),
  ('Аккорды к песне про лето, разобрать на гитаре', 'Музыка'),
  ('Купить билеты на самолёт до Стамбула, отель у моря', 'Путешествия'),
  ('Созвон с клиентом в 15:00, подготовить презентацию', 'Работа'),
  ('Курсовая по базам данных, сдать до сессии', 'Учёба'),
  ('Записаться к стоматологу, болит зуб', 'Здоровье'),
  ('Тренировка: приседания 4x10, отжимания 3x20', 'Спорт'),
  ('Плитка в ванную 20x20, сантехник придёт в четверг', 'Ремонт'),
  ('Поменять шины на зимние и пройти техосмотр', 'Машина'),
  ('Ипотека: платёж 15 числа, проверить перевод', 'Финансы'),
  ('Купить подгузники и записать сына в садик', 'Дети'),
  ('Кошке корм и наполнитель в лоток, к ветеринару в субботу', 'Питомцы'),
  ('забрать посылку на почте', 'Покупки'),
  // готовка делает продукты ингредиентами, а «купить» уступает тому, что покупают
  ('Сырники: творог, яйцо, мука, жарить на сковороде', 'Рецепты'),
  ('купить хлеб', 'Продукты'),
  ('купить подгузники', 'Дети'),
  ('buy cat litter', 'Питомцы'),
  ('купить зарядку для телефона', 'Покупки'),
  // промахи второй пачки на эмуляторе
  ('Героиня узнаёт, что отец всё это время работал на врага', 'Книга'),
  ('Бег 5 км, потом планка 2 минуты', 'Спорт'),
  ('nsfw арт посмотреть позже', '18+'),
  ('The detective finally realizes the butler lied about the knife', 'Книга'),
  ('lait, pain et fromage', 'Продукты'),
  ('latte, pane e formaggio', 'Продукты'),
  // промахи третьей пачки
  ('лабу по физике сдать преподу до зачёта', 'Учёба'),
  ('transfer rent to landlord before the 1st', 'Финансы'),
  ('plătește chiria și factura la internet', 'Финансы'),
  ('biglietto del treno per Milano', 'Путешествия'),
  // промахи четвёртой пачки: вещь ребёнка или зверя — в его папку
  ('глава 4 переписать, слишком затянуто, читатель заскучает', 'Книга'),
  ('налоговую декларацию подать до 15-го', 'Финансы'),
  ('сыну форму для футбола купить', 'Дети'),
  ('котёнку прививку в субботу', 'Питомцы'),
  ('дочке к врачу в среду', 'Дети'),
  ('take the dog to the vet for a vaccine', 'Питомцы'),
  // билеты бывают на что угодно: решает, куда они
  ('концерт в субботу, билеты в телефоне', 'Музыка'),
  ('кто заберёт посылку?', 'Покупки'),
  // «в машине» — место, где играл трек: имя папки не считается дважды, словом темы и именем
  ('скинуть Саше трек, который играл в машине', null),
  // по одному «зал», «ноги», «пресс» двусмысленны, вместе — тренировка
  ('в зал в 7, ноги и пресс', 'Спорт'),
  ('завтра спина и плечи, 4 подхода', 'Спорт'),
  ('legs and abs tonight', 'Спорт'),
  ('heute Beine und Bauch', 'Спорт'),
  ('болит спина и ноги', 'Здоровье'),
  ('концертный зал в центре', null),
  ('зал на свадьбу забронировать', null),
  // краска — ремонт только рядом со стеной или потолком
  ('покрасить стены в коридоре', 'Ремонт'),
  ('paint the bedroom walls', 'Ремонт'),
  ('купить краски для миниатюр', 'Покупки'),
  ('краски для картины по номерам', null),
  ('позвонить маме', null),
  ('пароль от вайфая на даче dacha2026', null),
  ('мысль: всё временно', null),
  // украинский
  ('Персонаж-лиходій має зрадити героїню в кінці', 'Книга'),
  ('хліб, яйця, ковбаса', 'Продукты'),
  ('Записатися до лікаря, купити ліки в аптеці', 'Здоровье'),
  ('Квитки на літак і готель у Львові', 'Путешествия'),
  ('Тренування: віджимання і присідання', 'Спорт'),
  ('подзвонити бабусі', null),
  // английский
  ('What if the villain is her brother? Reveal it in chapter 12', 'Книга'),
  ('milk, eggs, bread, bananas', 'Продукты'),
  ('Pancakes recipe: flour, milk, bake in oven', 'Рецепты'),
  ('Watch the new season of the series with that director', 'Кино'),
  ('Book a flight and hotel for the vacation', 'Путешествия'),
  ('Prepare the presentation for the client meeting, deadline Friday', 'Работа'),
  ('Dentist appointment, buy vitamins at the pharmacy', 'Здоровье'),
  ('Workout: squats and pushups, then yoga', 'Спорт'),
  ('Change the tires and renew car insurance', 'Машина'),
  ('Mortgage payment and taxes due next week', 'Финансы'),
  ('Vet for the puppy, buy kitten litter', 'Питомцы'),
  ('call Steve back', null),
  // немецкий
  ('Der Bösewicht verrät die Heldin im letzten Kapitel', 'Книга'),
  ('Milch, Brot, Eier, Käse', 'Продукты'),
  ('Rezept: Teig für Kuchen, im Ofen backen', 'Рецепты'),
  ('Flug und Hotel für den Urlaub buchen, Reisepass prüfen', 'Путешествия'),
  ('Zahnarzt anrufen, Tabletten aus der Apotheke holen', 'Здоровье'),
  ('Reifen wechseln und Werkstatt Termin', 'Машина'),
  ('Oma anrufen', null),
  // испанский
  ('El villano traiciona a la protagonista en el último capítulo', 'Книга'),
  ('leche, huevos, queso, arroz', 'Продукты'),
  ('Receta de sopa: hervir verduras, añadir ingredientes', 'Рецепты'),
  ('Reservar vuelo y hotel para las vacaciones', 'Путешествия'),
  ('Médico el lunes, comprar pastillas en la farmacia', 'Здоровье'),
  ('Llamar a mamá', null),
  // румынский
  ('Personajul negativ o trădează pe eroină în ultimul capitol', 'Книга'),
  ('lapte, pâine, ouă, brânză', 'Продукты'),
  ('Bilete de avion și hotel pentru vacanță la plajă', 'Путешествия'),
  ('Programare la dentist, pastile de la farmacie', 'Здоровье'),
  ('Schimb anvelopele la mașină și benzină', 'Машина'),
  ('Sună-l pe Ion', null),
  // польский
  ('Złoczyńca zdradzi bohaterkę w ostatnim rozdziale', 'Книга'),
  ('mleko, chleb, jajka, masło', 'Продукты'),
  ('Przepis na zupę, smażyć cebulę na patelni', 'Рецепты'),
  ('Bilet na samolot i hotel na wakacje, paszport', 'Путешествия'),
  ('Trening na siłowni: przysiady i pompki', 'Спорт'),
  ('Zadzwonić do mamy', null),
];

// французский, итальянский, португальский: словарей нет — главное не ошибиться папкой;
// общие корни («dentiste», «cliente») могут и попасть, это не ошибка
const _foreign = <(String, String?)>[
  ('Acheter du lait et du pain', 'Продукты'),
  ('Rendez-vous chez le dentiste mardi', 'Здоровье'),
  ('Comprare il latte e le uova', 'Продукты'),
  ('Prenotare il volo per le vacanze', 'Путешествия'),
  ('Ligar para a minha mãe amanhã', null),
  ('Reunião com o cliente na sexta', 'Работа'),
  ('Je pense à toi', null),
  ('Ci vediamo dopo', null),
];

// опечатки: буква мимо, лишняя, пропущенная, две соседние наоборот, не та раскладка, транслит
const _typos = <(String, String?)>[
  ('малоко и кифир', 'Продукты'),
  ('купить малоко', 'Продукты'),
  ('трениравка в семь', 'Спорт'),
  ('тренирвока ног', 'Спорт'),
  ('записатся к врчу', 'Здоровье'),
  ('злодей предаот героиню', 'Книга'),
  ('ветеренар для кота', 'Питомцы'),
  ('дедлаин по проекту', 'Работа'),
  ('screenhsot of the receipt', null),
  ('vegetabels and chiken', 'Продукты'),
  ('vjkjrj b [kt,', 'Продукты'),
  ('moloko i hleb', 'Продукты'),
  ('Termin beim Zahnartz', 'Здоровье'),
  ('Купить хлеп, купить колбасу, купить молоко', 'Продукты'),
  ('купить хлеп', 'Продукты'),
  ('хлеп и сыр', 'Продукты'),
  ('хлев почистить', null),
  // настоящие слова в одной букве от слов тем — не опечатки
  ('салют на новый год', null),
  ('новая парка на зиму', null),
  ('ложка и вилка', null),
  ('рука болит', 'Здоровье'),
  ('сломался замок', null),
  ('забрать посылку у соседа', 'Покупки'),
  ('корова на лугу', null),
  ('пакет из магазина', null),
];

// языки без перевода интерфейса: французский, итальянский, португальский, турецкий
const _moreLanguages = <(String, String?)>[
  ('Acheter des œufs, du beurre et de la farine', 'Продукты'),
  ('Réserver le vol et l’hôtel pour les vacances', 'Путешествия'),
  ('Rendez-vous chez le médecin, prendre les médicaments', 'Здоровье'),
  ('Réunion avec le client lundi, préparer le rapport', 'Работа'),
  ('Payer le loyer et les impôts', 'Финансы'),
  ('Le héros trahit le roi dans le dernier chapitre', 'Книга'),
  ('Regarder la nouvelle série ce soir', 'Кино'),
  ('Séance de sport: pompes et squats', 'Спорт'),
  ('Comprare uova, burro e farina', 'Продукты'),
  ('Prenotare l’albergo e il volo per Roma', 'Путешествия'),
  ('Appuntamento dal medico, comprare le medicine in farmacia', 'Здоровье'),
  ('Riunione con il cliente lunedì', 'Работа'),
  ('Pagare l’affitto e le tasse', 'Финансы'),
  ('L’eroina scopre il tradimento del re', 'Книга'),
  ('Allenamento: flessioni e squat in palestra', 'Спорт'),
  ('Il gatto deve andare dal veterinario', 'Питомцы'),
  ('Comprar ovos, manteiga e farinha', 'Продукты'),
  ('Consulta no dentista na terça', 'Здоровье'),
  ('Pagar o aluguel e os impostos', 'Финансы'),
  ('A heroína descobre a traição do rei', 'Книга'),
  ('Treino: flexões e agachamentos na academia', 'Спорт'),
  ('Ver o novo filme no cinema', 'Кино'),
  ('Süt, ekmek, peynir ve yumurta al', 'Продукты'),
  ('Uçak bileti ve otel rezervasyonu', 'Путешествия'),
  ('Doktor randevusu, eczaneden ilaç', 'Здоровье'),
  ('Müşteriyle toplantı, rapor hazırla', 'Работа'),
  ('Kira ve vergiler ödenecek', 'Финансы'),
  ('Kahraman kralı son bölümde aldatıyor', 'Книга'),
  ('Spor salonu: şınav ve mekik', 'Спорт'),
  ('Kediye mama ve veteriner', 'Питомцы'),
  ('À demain alors', null),
  ('Ci sentiamo stasera', null),
  ('Até logo, beijos', null),
  ('Yarın ararım', null),
];

// бытовое на всех языках: папки нет, и угадыватель не должен её придумать
const _everyday = <String>[
  'позвонить Пете насчёт выходных', 'не забыть ключи', 'мне нравится этот цвет', 'спросить у Лены про пятницу',
  'подумать над этим завтра', 'всё будет хорошо', 'вынести мусор',
  'зателефонувати Олені', 'не забути ключі',
  'call back later', 'remember the keys', 'I like this color', 'ask Anna about Friday', 'think about it tomorrow',
  'take out the trash', 'back in five minutes', 'let me know when you are free', 'per our conversation',
  'Schlüssel nicht vergessen', 'morgen nachdenken', 'Llamar más tarde', 'no olvidar las llaves', 'pensar mañana',
  'nu uita cheile', 'mă gândesc mâine', 'nie zapomnij kluczy', 'pomyśleć jutro', 'pas oublier les clés', 'pensaci domani',
];

// отложенная пачка: написана после словарей и под неё ничего не подгонялось
const _heldOut = <(String, String?)>[
  ('Сцена в таверне: наёмник узнаёт, что заказчик — его отец', 'Книга'),
  ('Ведьма не умирает, а теряет память. Так интереснее для второй части', 'Книга'),
  ('нужно докупить сметану и пару огурцов', 'Продукты'),
  ('гречка закончилась', 'Продукты'),
  ('Борщ как у бабушки: свёкла, капуста, тушить час', 'Рецепты'),
  ('хочу новые кроссовки, скидка до воскресенья', 'Покупки'),
  ('Интерстеллар пересмотреть в кинотеатре', 'Кино'),
  ('плейлист для пробежки', 'Музыка'),
  ('Маршрут по Грузии: Тбилиси, Казбеги, хостел в Батуми', 'Путешествия'),
  ('отчёт до пятницы, начальник просил графики', 'Работа'),
  ('конспект лекции по матанализу переписать', 'Учёба'),
  ('Сдать анализы натощак', 'Здоровье'),
  ('Бассейн по средам, 1000 метров', 'Спорт'),
  ('Обои в спальню и новый смеситель', 'Ремонт'),
  ('Заправка 40 литров, бензин подорожал', 'Машина'),
  ('Вернуть долг Саше 500 лей', 'Финансы'),
  ('Утренник в садике в пятницу, костюм зайца', 'Дети'),
  ('Щенку прививку и новый поводок', 'Питомцы'),
  ('In chapter three the dragon should finally speak', 'Книга'),
  ('out of eggs and butter', 'Продукты'),
  ('Soup tonight: simmer the stew for an hour', 'Рецепты'),
  ('Rewatch the trailer, premiere is next month', 'Кино'),
  ('New guitar chords for the chorus', 'Музыка'),
  ('Exam on Monday, revise lecture notes', 'Учёба'),
  ('Doctor said take vitamins for a month', 'Здоровье'),
  ('Gym at 7, then protein shake', 'Спорт'),
  ('Wallpaper for the bedroom, call the plumber', 'Ремонт'),
  ('Pay the loan and transfer rent', 'Финансы'),
  ('Kindergarten pickup at 5, buy toys for her birthday', 'Дети'),
  ('Ein neues Kapitel: die Heldin flieht nach Norden', 'Книга'),
  ('Kartoffeln und Zwiebeln holen', 'Продукты'),
  ('Prüfung nächste Woche, Vorlesung nachholen', 'Учёба'),
  ('Termin beim Arzt, Impfung', 'Здоровье'),
  ('Miete überweisen, Rechnung bezahlen', 'Финансы'),
  ('La protagonista descubre la traición del villano', 'Книга'),
  ('Comprar tomates y cebollas', 'Продукты'),
  ('Examen el viernes, repasar apuntes', 'Учёба'),
  ('Gimnasio: sentadillas y flexiones', 'Спорт'),
  ('Pagar la hipoteca y la factura de luz', 'Финансы'),
  ('Eroina descoperă trădarea în capitolul trei', 'Книга'),
  ('Cartofi, ceapă și usturoi pentru supă', 'Продукты'),
  ('Examen la facultate luni', 'Учёба'),
  ('Pisica are nevoie de veterinar', 'Питомцы'),
  ('Bohater traci pamięć w trzecim rozdziale', 'Книга'),
  ('Ziemniaki, cebula, czosnek', 'Продукты'),
  ('Egzamin w poniedziałek, wykład do nadrobienia', 'Учёба'),
  ('Przelew za czynsz i podatki', 'Финансы'),
  ('Нова глава: героїня тікає від лиходія', 'Книга'),
  ('Купити хліб і молоко', 'Продукты'),
  ('Іспит у понеділок, переписати конспект', 'Учёба'),
  // без папки
  ('Лена сказала, что всё в силе', null),
  ('напомнить себе отдохнуть', null),
  ('the wifi password is on the fridge', null),
  ('weekend plans?', null),
  ('Wie spät ist es dort?', null),
  ('¿Qué hacemos el sábado?', null),
  ('Ce facem diseară?', null),
  ('Co robimy w sobotę?', null),
];

({int right, int wrong, List<String> misses}) _run(FolderIndex index, List<(String, String?)> cases) {
  var right = 0;
  var wrong = 0;
  final misses = <String>[];
  for (final (text, expected) in cases) {
    final got = index.guess(text)?.folderId;
    if (got == expected) {
      right++;
    } else {
      if (got != null) wrong++;
      misses.add('${got ?? '—'} вместо ${expected ?? '—'}: $text');
    }
  }
  return (right: right, wrong: wrong, misses: misses);
}

void main() {
  final index = FolderIndex(const [], labels: [for (final name in _folders) FolderLabel(name, name)]);

  test('отложенная пачка: те же правила на заметках, под которые не подгоняли', () {
    final (:right, :wrong, :misses) = _run(index, _heldOut);
    // ignore: avoid_print
    print('отложенная: верно $right из ${_heldOut.length}, в чужую папку $wrong\n${misses.join('\n')}');
    expect(wrong, lessThanOrEqualTo(2));
    expect(right / _heldOut.length, greaterThanOrEqualTo(0.85));
  });

  test('пустые папки: заметки на семи языках ложатся по именам папок и темам', () {
    var right = 0;
    final misses = <String>[];
    var wrong = 0;
    for (final (text, expected) in _cases) {
      final got = index.guess(text)?.folderId;
      if (got == expected) {
        right++;
      } else {
        if (got != null) wrong++;
        misses.add('${got ?? '—'} вместо ${expected ?? '—'}: $text');
      }
    }
    // ignore: avoid_print
    print('верно $right из ${_cases.length}, ошибок в чужую папку $wrong\n${misses.join('\n')}');
    expect(wrong, lessThanOrEqualTo(1), reason: 'ошибиться папкой хуже, чем оставить без папки');
    expect(right / _cases.length, greaterThanOrEqualTo(0.9));
  });

  test('чужие языки без словарей — не ошибаются папкой', () {
    final wrong = [
      for (final (text, expected) in _foreign)
        if (index.guess(text)?.folderId case final got? when got != expected) '$got вместо ${expected ?? '—'}: $text',
    ];
    // ignore: avoid_print
    print('чужие языки, ошибки: $wrong');
    expect(wrong, isEmpty);
  });

  test('опечатки, раскладка и транслит узнаются, настоящие слова-соседи — нет', () {
    final (:right, :wrong, :misses) = _run(index, _typos);
    // ignore: avoid_print
    print('опечатки: верно $right из ${_typos.length}, в чужую папку $wrong\n${misses.join('\n')}');
    expect(wrong, 0);
    expect(right / _typos.length, greaterThanOrEqualTo(0.85));
  });

  test('языки без перевода интерфейса тоже раскладываются', () {
    final (:right, :wrong, :misses) = _run(index, _moreLanguages);
    // ignore: avoid_print
    print('ещё языки: верно $right из ${_moreLanguages.length}, в чужую папку $wrong\n${misses.join('\n')}');
    expect(wrong, 0);
    expect(right / _moreLanguages.length, greaterThanOrEqualTo(0.85));
  });

  test('бытовое на десяти языках остаётся без папки', () {
    final sorted = [
      for (final text in _everyday)
        if (index.guess(text) case final guess?) '${guess.folderId}: $text',
    ];
    // ignore: avoid_print
    print('бытовое разложено: $sorted');
    expect(sorted, isEmpty);
  });
}
