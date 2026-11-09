/// Темы без ИИ: словари на семи языках (ru, uk, en, de, es, ro, pl). По имени папки
/// видно, про что она («Продукты», «Groceries», «Zakupy spożywcze» — продукты),
/// по словам заметки — про что она («молоко», «eggs», «Brot»). Совпали — заметка
/// тянется в папку с первого дня, даже пока в папке ничего нет.
///
/// В словари идут только однозначные слова: «масло» есть и у продуктов, и у машины,
/// «зал» — и спортзал, и концертный, поэтому таких слов здесь нет.
library;

import 'line_query.dart' show normalizeQuery, stem;

enum Topic {
  books,
  groceries,
  cooking,
  shopping,
  films,
  music,
  travel,
  work,
  study,
  health,
  sport,
  home,
  car,
  money,
  kids,
  pets,
  adult,
}

/// Как называют папку этой темы.
const _names = <Topic, String>{
  Topic.books:
      'книга книги книжки роман романы рассказ рассказы писательство чтение черновики сюжеты '
      'книжка книжки розповіді '
      'book books novel novels writing reading story stories manuscript '
      'buch bücher lesen schreiben libro libros novela lectura escritura carte cărți lectură scriere '
      'książka książki powieść lektura pisanie',
  Topic.groceries:
      'продукты еда продуктовый провизия продукти їжа groceries grocery food foods '
      'lebensmittel essen comida alimentos mercado alimente mâncare jedzenie spożywcze',
  Topic.cooking:
      'рецепты рецепт кулинария готовка блюда рецепти кулінарія recipes recipe cooking cookbook '
      'rezepte rezept kochen recetas receta cocina rețete gătit przepisy przepis gotowanie',
  Topic.shopping:
      'покупки шопинг хотелки вишлист заказы покупки замовлення shopping purchases wishlist orders '
      'einkäufe einkaufen wunschliste compras pedidos cumpărături comenzi zakupy zamówienia',
  Topic.films:
      'кино фильмы сериалы мультики кіно фільми серіали movies movie films series cinema '
      'filme serien kino películas cine series filme seriale filmy seriale',
  Topic.music: 'музыка песни треки музика пісні music songs tracks musik lieder música canciones muzică cântece muzyka piosenki',
  Topic.travel:
      'путешествия путешествие поездки отпуск туризм подорожі подорож відпустка travel travels trips trip vacation '
      'reisen reise urlaub viajes viaje vacaciones călătorii vacanță podróże wakacje',
  Topic.work: 'работа работы робота work job jobs arbeit job trabajo muncă serviciu praca',
  Topic.study:
      'учеба учёба колледж универ университет институт школа навчання університет study studies school college university '
      'studium uni schule estudios universidad facultate școală studia uczelnia szkoła',
  Topic.health: 'здоровье медицина врачи здоров’я здоровя медицина health medical medicine gesundheit salud sănătate zdrowie',
  Topic.sport:
      'спорт тренировки фитнес спортзал тренування sport sports fitness gym workout workouts training '
      'deporte entrenamiento sală antrenament trening siłownia',
  Topic.home:
      'дом ремонт квартира дача хозяйство дім квартира home house renovation repairs '
      'haus wohnung renovierung casa hogar reforma casă apartament renovare dom mieszkanie remont',
  Topic.car: 'машина авто автомобиль тачка автомобіль car cars auto vehicle coche mașină samochód',
  Topic.money:
      'финансы деньги бюджет долги расходы счета фінанси гроші витрати finance finances money budget expenses '
      'finanzen geld ausgaben finanzas dinero gastos finanțe bani cheltuieli finanse pieniądze wydatki',
  Topic.kids: 'дети ребенок ребёнок малыш діти дитина kids children child baby kinder kind niños bebé copii copil dzieci dziecko',
  Topic.pets: 'питомцы животные кот кошка собака тварини pets pet animals cat dog haustiere mascotas animale zwierzęta',
  Topic.adult: 'взрослое nsfw xxx adult erotica эротика',
};

/// Слова заметки, по которым видно тему.
const _words = <Topic, String>{
  Topic.books:
      // сюжет и герои: идея книги обычно говорит о них, а не о самой книге
      'герой героиня героини персонаж персонажи сюжет сюжетная злодей антагонист протагонист пролог эпилог '
      'концовка рукопись черновик повесть рассказ писатель предательство предать предаст предал '
      'предала влюбится влюбилась королевство дракон дракона магия заклинание пророчество ведьма эльф '
      'перечитать дочитать роман таверна таверне наемник наёмник рыцарь рыцаря принцесса трон империя гильдия орк '
      'заговор флешбэк '
      'герой героїня персонаж сюжет лиходій рукопис чернетка зрада зрадить королівство дракон магія '
      'novel chapter chapters character characters protagonist antagonist villain plot subplot prologue epilogue '
      'manuscript storyline worldbuilding heroine betray betrays betrayed betrayal kingdom dragon wizard prophecy reread '
      'kapitel figur figuren protagonist bösewicht handlung prolog epilog manuskript heldin verrat verrät drache zauber '
      'novela capítulo personaje personajes protagonista villano trama prólogo epílogo manuscrito heroína traición traiciona dragón hechizo '
      'capitol personaj personaje protagonist răufăcător intrigă prolog epilog manuscris eroină trădare trădează dragon vrajă '
      'powieść rozdział postać postacie bohater bohaterka protagonista złoczyńca fabuła prolog epilog rękopis zdrada zdradzi smok zaklęcie',
  Topic.groceries:
      'молоко хлеб батон яйца яиц сыр творог кефир йогурт сметана ряженка мука сахар соль гречка макароны '
      'курица куриное фарш колбаса сосиски овощи фрукты картошка картофель морковь чеснок помидоры огурцы '
      'яблоки бананы апельсины лимоны лимон чай сок печенье шоколадка продукты '
      'хліб яйця борошно цукор гречка курка ковбаса овочі фрукти картопля морква цибуля часник помідори огірки яблука банани '
      'milk bread eggs cheese butter flour sugar rice chicken beef sausage yogurt vegetables fruit potatoes carrots onions '
      'garlic tomatoes cucumbers apples bananas oranges lemons juice groceries '
      'milch brot eier käse mehl zucker reis hähnchen wurst joghurt gemüse obst kartoffeln karotten zwiebeln knoblauch '
      'tomaten gurken äpfel bananen saft '
      'leche huevos queso mantequilla harina azúcar arroz pollo salchichas yogur verduras frutas patatas zanahorias '
      'cebollas tomates pepinos manzanas plátanos zumo '
      'lapte pâine ouă brânză făină zahăr orez pui cârnați iaurt legume fructe cartofi morcovi ceapă usturoi roșii castraveți mere banane '
      'mleko chleb jajka mąka cukier ryż kurczak kiełbasa jogurt warzywa owoce ziemniaki marchew cebula czosnek pomidory ogórki jabłka banany',
  Topic.cooking:
      'рецепт варить сварить жарить пожарить запечь запекать духовке духовка сковороде сковорода кастрюле тесто '
      'начинка приправа специи нарезать обжарить тушить блины суп борщ салат пирог торт выпечка ингредиенты '
      'рецепт варити смажити запекти духовка сковорода тісто суп салат пиріг інгредієнти '
      'recipe bake baking boil fry roast oven skillet dough seasoning simmer stew pancakes soup salad pie cake ingredients tablespoon teaspoon '
      'rezept kochen braten ofen pfanne teig suppe salat kuchen zutaten esslöffel '
      'receta hornear hervir freír horno sartén sopa ensalada tarta ingredientes cucharada '
      'rețetă coace fierbe prăjește cuptor tigaie aluat supă salată prăjitură ingrediente '
      'przepis smażyć piekarnik patelnia ciasto zupa sałatka składniki łyżka',
  Topic.shopping:
      'купить заказать заказ доставка скидка распродажа маркетплейс озон вайлдберриз алиэкспресс посылка '
      'купити замовити доставка знижка розпродаж '
      'buy delivery discount sale amazon aliexpress temu wishlist '
      'kaufen bestellen lieferung rabatt angebot comprar pedido envío descuento rebajas cumpăr cumpără comandă livrare reducere '
      'kupić zamówić zamówienie dostawa rabat promocja',
  Topic.films:
      'фильм фильмы кино сериал сериала сезон режиссер режиссёр актер актёр актриса трейлер посмотреть премьера мультфильм аниме кинотеатр '
      'фільм кіно серіал режисер актор трейлер мультфільм '
      'movie movies film series episode season director actor actress trailer premiere cartoon anime cinema netflix '
      'serie folge staffel regisseur schauspieler kino película series episodio temporada actriz tráiler cine '
      'serial episod sezon regizor actriță cinematograf serial odcinek sezon reżyser aktor aktorka zwiastun kino',
  Topic.music:
      'песня песни музыка альбом трек треки плейлист концерт исполнитель гитара аккорды '
      'пісня музика альбом концерт гітара '
      'song songs music album playlist concert singer guitar chords lyrics spotify '
      ' lieder musik konzert sänger gitarre canción canciones música concierto cantante guitarra '
      'cântec melodie muzică concert chitară piosenka muzyka koncert gitara',
  Topic.travel:
      'поездка поездку путешествие отпуск билеты самолет самолёт рейс аэропорт отель гостиница виза паспорт чемодан '
      'маршрут пляж экскурсия хостел '
      'подорож відпустка квиток квитки літак рейс аеропорт готель віза паспорт валіза '
      'trip travel vacation flight airport hotel visa passport luggage itinerary beach hostel booking '
      'reise urlaub flug flughafen visum reisepass koffer strand viaje vacaciones vuelo aeropuerto visado pasaporte maleta playa '
      'călătorie vacanță zbor aeroport viză pașaport valiză plajă podróż wakacje lotnisko wiza paszport walizka plaża',
  Topic.work:
      'работа работе созвон митинг дедлайн проект клиент отчет отчёт презентация коллега начальник офис '
      'собеседование резюме '
      'робота зустріч дедлайн проєкт клієнт звіт презентація колега офіс '
      'meeting deadline project client report presentation colleague manager office interview '
      'arbeit besprechung projekt kunde bericht präsentation kollege büro trabajo reunión proyecto cliente informe presentación colega oficina '
      'muncă ședință proiect client raport prezentare coleg birou praca projekt klient raport prezentacja biuro',
  Topic.study:
      'учеба учёба лекция семинар экзамен зачет зачёт сессия курсовая диплом домашка преподаватель университет колледж '
      'конспект лабораторная '
      'навчання лекція семінар іспит залік курсова диплом університет коледж конспект '
      'lecture seminar exam homework thesis professor university college '
      'vorlesung prüfung hausaufgaben universität examen deberes universidad apuntes '
      'facultate curs seminar examen universitate wykład egzamin uczelnia kolokwium',
  Topic.health:
      'врач врачу доктор больница поликлиника анализы таблетки лекарство лекарства аптека давление '
      'стоматолог прививка витамины симптомы болит '
      'лікар лікарня аптека таблетки ліки стоматолог щеплення '
      'doctor hospital clinic pharmacy pills medicine prescription dentist vaccine vitamins symptoms '
      'arzt krankenhaus apotheke tabletten medikament zahnarzt impfung médico hospital farmacia pastillas medicamento dentista vacuna '
      'medic spital farmacie pastile medicament dentist vaccin lekarz szpital apteka tabletki lekarstwo dentysta szczepienie',
  Topic.sport:
      'тренировка тренировку спортзал пробежка пробежку отжимания приседания подтягивания бицепс растяжка йога '
      'футбол бассейн калории протеин '
      'тренування спортзал біг віджимання присідання йога '
      'workout gym running pushups squats yoga football swimming calories protein '
      'training fitnessstudio liegestütze kniebeugen entrenamiento gimnasio flexiones sentadillas '
      'antrenament alergare flotări genuflexiuni trening siłownia bieganie pompki przysiady',
  Topic.home:
      'ремонт плитка плитку обои краска покрасить шпаклевка штукатурка ламинат розетка смеситель сантехник электрик '
      'мебель диван шкаф ванная квартира аренда коммуналка '
      'ремонт плитка шпалери фарба сантехнік меблі диван ванна квартира оренда '
      'renovation repair tiles wallpaper paint plumber electrician furniture sofa wardrobe bathroom apartment rent '
      'renovierung reparatur fliesen tapete farbe klempner möbel sofa wohnung miete '
      'reforma reparación azulejos pintura fontanero muebles sofá baño piso alquiler '
      'renovare reparație faianță tapet vopsea instalator mobilă canapea baie apartament chirie '
      'remont płytki tapeta farba hydraulik meble kanapa łazienka mieszkanie czynsz',
  Topic.car:
      'машина машину автомобиль шины резина моторное техосмотр страховка бензин заправка гараж автосервис '
      'автомобіль шини бензин гараж '
      'car tires tyres engine insurance gasoline fuel garage mechanic '
      'auto reifen motoröl werkstatt tanken coche neumáticos gasolina '
      'mașină mașina anvelope benzină samochód opony benzyna warsztat',
  Topic.money:
      'деньги долг долги кредит ипотека банк перевод оплата платеж платёж бюджет расходы доходы налоги вклад инвестиции '
      'гроші борг кредит іпотека банк переказ оплата бюджет податки '
      'money debt loan mortgage bank transfer payment budget expenses income taxes savings invest '
      'geld schulden kredit überweisung zahlung rechnung steuern dinero deuda préstamo hipoteca banco transferencia pago factura impuestos '
      'bani datorie credit ipotecă bancă plată factură taxe pieniądze dług kredyt przelew płatność rachunek podatki',
  Topic.kids:
      'ребенок ребёнок дети сын дочка садик детсад утренник игрушки подгузники педиатр коляска '
      'дитина діти син донька садочок іграшки '
      'kids child children son daughter kindergarten toys diapers pediatrician stroller '
      'kinder kindergarten spielzeug windeln niños hijo hija guardería juguetes pañales '
      'copii copil fiu fiică grădiniță jucării scutece dzieci dziecko syn córka przedszkole zabawki pieluchy',
  Topic.pets:
      // у «щенок», «котёнок» гласная выпадает: «щенку», «котёнка» — свои основы
      'кот кота коту кошка кошку собака собаку собаке щенок щенка щенку щенки котенок котёнок котенка котёнка котенку '
      'котёнку ветеринар ветеринару корм лоток поводок поводка ошейник '
      'кіт кішка собака цуценя ветеринар корм '
      'cat cats dog dogs puppy kitten vet litter '
      'katze hund welpe tierarzt futter gato perro cachorro veterinario pienso pisică câine cățel veterinar kot szczeniak weterynarz ',
  Topic.adult:
      'порно эротика секс nsfw porn porno xxx hentai onlyfans erotik erotica',
};

/// Основа короче этого совпадает с обычными словами других языков: «per» (итальянское
/// «для») — основа испанского «perro», «back» — немецкого «backen». Такие слова
/// сравниваются целиком, а не по основе.
const _shortStem = 4;

({Map<String, Set<Topic>> stems, Map<String, Set<Topic>> whole}) _index(Map<Topic, String> source) {
  final stems = <String, Set<Topic>>{};
  final whole = <String, Set<Topic>>{};
  for (final MapEntry(key: topic, value: words) in source.entries) {
    for (final word in words.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final folded = normalizeQuery(word);
      final base = stem(folded);
      if (base.length >= _shortStem) stems.putIfAbsent(base, () => {}).add(topic);
      whole.putIfAbsent(folded, () => {}).add(topic);
    }
  }
  return (stems: stems, whole: whole);
}

final _nameIndex = _index(_names);
final _wordIndex = _index(_words);

Set<Topic> _lookup(({Map<String, Set<Topic>> stems, Map<String, Set<Topic>> whole}) index, String word) {
  final folded = normalizeQuery(word);
  return {...?index.whole[folded], ...?index.stems[stem(folded)]};
}

// «18+», «NSFW 🔞»: цифры и знаки словами не разобрать
final _adultName = RegExp(r'18\s*\+|🔞|nsfw|xxx', caseSensitive: false);

/// Про что папка по её имени: «Продукты» — продукты, «Книга про Милтона» — книги.
Set<Topic> topicsOfName(String name) => {
  if (_adultName.hasMatch(name)) Topic.adult,
  for (final word in name.split(RegExp(r'[^\p{L}]+', unicode: true)))
    if (word.length >= 2) ..._lookup(_nameIndex, word),
};

/// Темы одного слова заметки: целиком или по основе от четырёх букв.
Set<Topic> topicsOfWord(String word) => _lookup(_wordIndex, word);
