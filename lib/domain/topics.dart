/// Темы без ИИ: словари на семи языках интерфейса (ru, uk, en, de, es, ro, pl) и
/// словами — ещё на французском, итальянском, португальском и турецком. По имени папки
/// видно, про что она («Продукты», «Groceries», «Zakupy spożywcze» — продукты),
/// по словам заметки — про что она («молоко», «eggs», «Brot»). Совпали — заметка
/// тянется в папку с первого дня, даже пока в папке ничего нет.
///
/// В словари идут только однозначные слова: «масло» есть и у продуктов, и у машины,
/// «зал» — и спортзал, и концертный, поэтому таких слов здесь нет.
library;

import 'line_query.dart' show nearWords, normalizeQuery, stem;
import 'typo_neighbors.dart';
import 'word_variants.dart' show swapLayouts, toCyrillic;

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
      'заговор флешбэк читатель читателя читателю читатели '
      'герой героїня персонаж сюжет лиходій рукопис чернетка зрада зрадить королівство дракон магія '
      'novel chapter chapters character characters protagonist antagonist villain plot subplot prologue epilogue '
      'manuscript storyline worldbuilding heroine betray betrays betrayed betrayal kingdom dragon wizard prophecy reread '
      'kapitel figur figuren protagonist bösewicht handlung prolog epilog manuskript heldin verrat verrät drache zauber '
      'novela capítulo personaje personajes protagonista villano trama prólogo epílogo manuscrito heroína traición traiciona dragón hechizo '
      'capitol personaj personaje protagonist răufăcător intrigă prolog epilog manuscris eroină trădare trădează dragon vrajă '
      'powieść rozdział postać postacie bohater bohaterka protagonista złoczyńca fabuła prolog epilog rękopis zdrada zdradzi smok zaklęcie '
      'враг врага врагу врагом врагов детектив убийца '
      'detective murderer killer suspect '
      // «roi» — ещё и окупаемость, «roman» — имя: их нет
      'héros héroïne chapitre personnage intrigue trahit trahison méchant royaume sorcière '
      'eroina eroe capitolo personaggio trama romanzo tradimento tradisce cattivo regno strega '
      'herói capítulo personagem enredo traição vilão reino bruxa '
      'kahraman kahramanı bölüm bölümde bölümü ihanet kral kralı aldatıyor ejderha büyücü',
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
      'mleko chleb jajka mąka cukier ryż kurczak kiełbasa jogurt warzywa owoce ziemniaki marchew cebula czosnek pomidory ogórki jabłka banany '
      // французское «pain» — ещё и английская боль: его нет
      'lait fromage oeufs œufs beurre farine sucre poulet légumes pommes baguette '
      'latte pane formaggio uova burro farina zucchero riso pollo verdure frutta patate '
      'leite pão queijo ovos manteiga farinha açúcar frango legumes batatas maçãs '
      'süt ekmek peynir yumurta tereyağı şeker pirinç tavuk sebze meyve patates elma',
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
      // «lieder» нет: его основа «lied» — английское «солгал»
      'musik konzert sänger gitarre canción canciones música concierto cantante guitarra '
      'cântec melodie muzică concert chitară piosenka muzyka koncert gitara',
  Topic.travel:
      // билетов нет: они и в кино, и на концерт — поездку видно по самолёту, поезду, отелю
      'поездка поездку путешествие отпуск самолет самолёт рейс аэропорт отель гостиница виза паспорт чемодан '
      'маршрут пляж экскурсия хостел '
      'подорож відпустка потяг літак рейс аеропорт готель віза паспорт валіза '
      'trip travel vacation flight airport hotel visa passport luggage itinerary beach hostel booking '
      'reise urlaub flug flughafen visum reisepass koffer strand viaje vacaciones vuelo aeropuerto visado pasaporte maleta playa '
      'călătorie vacanță zbor aeroport viză pașaport valiză plajă podróż wakacje lotnisko wiza paszport walizka plaża '
      'vacances aéroport valise plage albergo volo vacanze aeroporto valigia spiaggia treno '
      'поезд поезда поезде '
      'viagem férias voo aeroporto passaporte praia '
      'uçak uçuş tatil otel rezervasyon rezervasyonu havalimanı pasaport vize bavul plaj',
  Topic.work:
      'работа работе созвон митинг дедлайн проект клиент отчет отчёт презентация коллега начальник офис '
      'собеседование резюме '
      'робота зустріч дедлайн проєкт клієнт звіт презентація колега офіс '
      'meeting deadline project client report presentation colleague manager office interview '
      'arbeit besprechung projekt kunde bericht präsentation kollege büro trabajo reunión proyecto cliente informe presentación colega oficina '
      'muncă ședință proiect client raport prezentare coleg birou praca projekt klient raport prezentacja biuro '
      'réunion rapport bureau collègue riunione progetto rapporto ufficio collega reunião projeto relatório escritório '
      'toplantı toplantısı müşteri müşteriyle rapor sunum proje ofis',
  Topic.study:
      'учеба учёба лекция семинар экзамен зачет зачёт сессия курсовая диплом домашка преподаватель университет колледж '
      'конспект лабораторная '
      // «зачёт» стеммер режет до «зач»: падежи списком
      'зачета зачёта зачету зачёту лаба лабу лабы лабораторку препод препода преподу физика физике физику химия химии '
      'алгебра алгебре геометрия матанализ '
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
      'medic spital farmacie pastile medicament dentist vaccin lekarz szpital apteka tabletki lekarstwo dentysta szczepienie '
      'médecin médicaments pharmacie dentiste hôpital medico medicine farmacia ospedale dentista '
      'remédio farmácia hospital '
      'doktor doktora eczane eczaneden ilaç hastane',
  Topic.sport:
      'тренировка тренировку спортзал пробежка пробежку отжимания приседания подтягивания бицепс растяжка йога '
      'футбол бассейн калории протеин '
      'тренування спортзал біг віджимання присідання йога '
      'workout gym running pushups squats yoga football swimming calories protein '
      'training fitnessstudio liegestütze kniebeugen entrenamiento gimnasio flexiones sentadillas '
      'antrenament alergare flotări genuflexiuni trening siłownia bieganie pompki przysiady '
      'бег бегать планка планку кардио '
      'pompes musculation allenamento palestra flessioni treino flexões agachamentos '
      'antrenman şınav mekik koşu',
  Topic.home:
      // краска и «покрасить» — в слабых: красят и стены, и миниатюры, и картины
      'ремонт плитка плитку обои шпаклевка штукатурка ламинат розетка смеситель сантехник электрик '
      // аренда и коммуналка — платежи, они у денег
      'мебель диван шкаф ванная квартира '
      'ремонт плитка шпалери сантехнік меблі диван ванна квартира '
      'renovation repair tiles wallpaper plumber electrician furniture sofa wardrobe bathroom apartment '
      'renovierung reparatur fliesen tapete klempner möbel sofa wohnung '
      'reforma reparación azulejos fontanero muebles sofá baño piso '
      'renovare reparație faianță tapet instalator mobilă canapea baie apartament '
      'remont płytki tapeta hydraulik meble kanapa łazienka mieszkanie',
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
      'bani datorie credit ipotecă bancă plată factură taxe pieniądze dług kredyt przelew płatność rachunek podatki '
      // итальянского «tasse» нет: по-немецки это чашка
      'loyer impôts impots facture banque virement prêt dette hypothèque affitto bolletta banca bonifico prestito mutuo debito '
      'aluguel aluguer impostos dívida empréstimo '
      'vergi vergiler fatura borç kredi '
      'аренда аренду коммуналка коммуналку квартплата оренда rent landlord miete alquiler chirie chiria czynsz '
      'налоговая налоговую налоговой декларация декларацию',
  Topic.kids:
      'ребенок ребёнок дети сын дочка садик детсад утренник игрушки подгузники педиатр коляска '
      // «сын» из трёх букв по основе не узнаётся: падежи списком
      'сына сыну сыном дочке дочку дочки дочери дочь ребенку ребёнку ребенка ребёнка детям детей малыша малышу '
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
      'katze hund welpe tierarzt futter gato perro cachorro veterinario pienso pisică câine cățel veterinar kot szczeniak weterynarz '
      // «chat» по-английски разговор, «cane» — трость, «mele» по-румынски «мои»: их нет
      'chien chiot vétérinaire gatto cucciolo veterinario cão cachorro '
      'kedi kediye köpek köpeğe veteriner',
  Topic.adult:
      'порно эротика секс nsfw porn porno xxx hentai onlyfans erotik erotica',
};

/// Слова, двусмысленные поодиночке, но ясные парой: «зал» бывает концертным, «ноги» —
/// у кого угодно, а «зал, ноги и пресс» — тренировка.
const _weakWords = <Topic, String>{
  Topic.sport:
      'зал зале ноги ног ногам пресс спина спину плечи грудь подход подхода подходов подходы повторений жим тяга '
      'зал залі ноги прес спина плечі груди підходи '
      'legs abs chest shoulders sets reps bench '
      'beine bauch brust rücken schultern sätze '
      'piernas abdominales pecho espalda hombros '
      'picioare abdomene piept spate umeri '
      'nogi brzuch klatka plecy barki serie '
      'jambes abdos pectoraux épaules gambe addominali petto spalle pernas abdominais peito costas ombros '
      'bacak karın göğüs sırt omuz',
  // «покрасить стены» — ремонт, «покрасить космодесантников» — нет
  Topic.home:
      'краска краску покрасить покрасили стены стену потолок пол полы '
      'фарба фарбу пофарбувати стіни стелю '
      'paint painting walls wall ceiling floor '
      'farbe streichen wände wand decke boden '
      'pintura pintar paredes pared techo suelo '
      'vopsea vopsit pereți perete tavan podea '
      'farba pomalować ściany ścianę sufit podłoga '
      'peinture peindre murs plafond pittura pitturare pareti soffitto tinta pintar paredes teto '
      'boya boyamak duvar duvarlar tavan',
};

final _weakIndex = _index(_weakWords);

/// Темы, которые слово даёт только в паре с другим таким же (см. [_weakWords]).
Set<Topic> weakTopicsOfWord(String word) => _lookup(_weakIndex, word);

/// Основа короче этого совпадает с обычными словами других языков: «per» (итальянское
/// «для») — основа испанского «perro», «back» — немецкого «backen». Такие слова
/// сравниваются целиком, а не по основе.
const _shortStem = 4;

// окончания глагола, приставленные к целому существительному: «работа» → «работал»,
// «работает»; «кот» → «котла» (котёл) — тоже не кот
const _verbTails = {'л', 'ла', 'ли', 'ло', 'ть', 'ться', 'ет', 'ют', 'ем', 'ешь', 'ете', 'лся', 'лась', 'лись', 'ed', 'ing'};

/// [word] — глагол от существительного [noun] (оба свёрнуты `normalizeQuery`):
/// у них одна основа, но «работал на врага» не про работу.
bool isVerbOf(String word, String noun) => word.length > noun.length && word.startsWith(noun) && _verbTails.contains(word.substring(noun.length));

typedef _Index = ({
  Map<String, Set<Topic>> stems,
  Map<String, Set<Topic>> whole,
  Map<String, Set<String>> forms,
  // слова и основы от шести букв по первой букве: опечатку ищем только среди них
  Map<String, Map<String, Set<Topic>>> nearWhole,
  Map<String, Map<String, Set<Topic>>> nearStems,
  // уже разобранные слова: строка угадывает на каждое нажатие одно и то же
  Map<String, Set<Topic>> memo,
});

_Index _index(Map<Topic, String> source) {
  final stems = <String, Set<Topic>>{};
  final whole = <String, Set<Topic>>{};
  final forms = <String, Set<String>>{};
  for (final MapEntry(key: topic, value: words) in source.entries) {
    for (final word in words.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final folded = normalizeQuery(word);
      final base = stem(folded);
      if (base.length >= _shortStem) {
        stems.putIfAbsent(base, () => {}).add(topic);
        forms.putIfAbsent(base, () => {}).add(folded);
      }
      whole.putIfAbsent(folded, () => {}).add(topic);
    }
  }
  Map<String, Map<String, Set<Topic>>> byFirst(Map<String, Set<Topic>> words) {
    final buckets = <String, Map<String, Set<Topic>>>{};
    for (final MapEntry(key: word, value: topics) in words.entries) {
      if (word.length >= _typoLength) buckets.putIfAbsent(word[0], () => {})[word] = topics;
    }
    return buckets;
  }

  return (stems: stems, whole: whole, forms: forms, nearWhole: byFirst(whole), nearStems: byFirst(stems), memo: <String, Set<Topic>>{});
}

final _nameIndex = _index(_names);
final _wordIndex = _index(_words);

/// Сколько разобранных слов помнить; больше — память чистится целиком.
const _memoSize = 20000;

Set<Topic> _lookup(_Index index, String word) {
  final folded = normalizeQuery(word);
  if (index.memo[folded] case final topics?) return topics;
  if (index.memo.length >= _memoSize) index.memo.clear();
  return index.memo[folded] = _find(index, folded);
}

Set<Topic> _find(_Index index, String folded) {
  final own = _exactly(index, folded);
  if (own != null) return own;
  // длиннее слов не бывает даже у немцев: это ключ, хеш или вставленный мусор
  if (folded.length > _longestWord) return const {};
  // набрано не в той раскладке («vjkjrj» — «молоко») или транслитом («moloko»)
  for (final variant in _variantsOf(folded)) {
    if (_exactly(index, variant) case final topics?) return topics;
  }
  return _typo(index, folded);
}

// основа и варианты слова общие для всех словарей: считаются раз на слово
final _stems = <String, String>{};
final _variants = <String, List<String>>{};
final _cyrillic = RegExp('[а-яіїєґ]');

String _stemOf(String folded) {
  if (_stems.length >= _memoSize) _stems.clear();
  return _stems[folded] ??= stem(folded);
}

List<String> _variantsOf(String folded) {
  if (_variants.length >= _memoSize) _variants.clear();
  return _variants[folded] ??= [
    for (final variant in [...swapLayouts(folded), if (!_cyrillic.hasMatch(folded) && folded.length >= 4) toCyrillic(folded)]) normalizeQuery(variant),
  ];
}

// само слово целиком или по основе; null — словарь его не знает
Set<Topic>? _exactly(_Index index, String folded) {
  // слово есть в словаре целиком — основа не нужна: «treno» и польское «trening»
  // сходятся в «tren», но поезд — не тренировка
  if (index.whole[folded] case final topics?) return topics;
  final base = _stemOf(folded);
  final verb = index.forms[base]?.any((form) => isVerbOf(folded, form)) ?? false;
  if (verb) return const {};
  return index.stems[base];
}

const _longestWord = 40;

/// Опечатка узнаётся у слова или основы от шести букв: у коротких слишком много
/// настоящих соседей («мука» — «рука», «салат» — «салют», «color» — «calor(ies)»).
const _typoLength = 6;

// опечатка: слово или основа в одну букву или в две соседние наоборот от слова
// словаря, с той же первой буквой (её путают реже всего) и только одной темы.
// Слово целиком и основа — обе: стеммер режет «chiken» и «chicken» по-разному
Set<Topic> _typo(_Index index, String folded, {bool neighbors = true}) {
  // настоящее слово в одной букве от слова темы — не опечатка: «весьма» не «ведьма»,
  // «summer» не «simmer». Список собран из словарей 11 языков
  if (neighbors && typoNeighbors.contains(_stemOf(folded))) return const {};
  final found = <Topic>{};
  void near(String word, Map<String, Map<String, Set<Topic>>> buckets) {
    if (word.length < _typoLength) return;
    for (final MapEntry(key: other, value: topics) in (buckets[word[0]] ?? const {}).entries) {
      if ((other.length - word.length).abs() > 1) continue;
      // «концертный» — не опечатка «концерта», а другое слово от него
      if (other.startsWith(word) || word.startsWith(other)) continue;
      if (typoOf(word, other)) found.addAll(topics);
    }
  }

  near(folded, index.nearWhole);
  near(_stemOf(folded), index.nearStems);
  return found.length == 1 ? found : const {};
}

/// Темы, которые слово получает только как опечатка: само оно словарю не знакомо.
/// Для замера на настоящих словах — обычное слово сюда попадать не должно.
/// [neighbors] false — без списка исключений: так его собирает `tool/typo_neighbors_test.dart`.
Set<Topic> topicsByTypo(String word, {bool neighbors = true}) {
  final folded = normalizeQuery(word);
  if (_exactly(_wordIndex, folded) != null || _exactly(_weakIndex, folded) != null) return const {};
  return {..._typo(_wordIndex, folded, neighbors: neighbors), ..._typo(_weakIndex, folded, neighbors: neighbors)};
}

/// Основа из [known], опечаткой которой может быть [stem]: ровно одна, от шести букв,
/// с той же первой буквой, не продолжение слова и не настоящее слово-сосед.
/// Для слов, которым угадыватель научился на заметках, и для имён папок.
String? typoMatch(String stem, Iterable<String> known) {
  if (stem.length < _typoLength || stem.length > _longestWord || typoNeighbors.contains(stem)) return null;
  String? found;
  for (final other in known) {
    if (other.length < _typoLength || other[0] != stem[0] || (other.length - stem.length).abs() > 1) continue;
    if (other.startsWith(stem) || stem.startsWith(other) || !typoOf(stem, other)) continue;
    if (found != null) return null;
    found = other;
  }
  return found;
}

/// [a] и [b] различаются одной буквой (замена, лишняя, пропущенная) или двумя
/// соседними, переставленными местами: «малоко» — «молоко», «тренирвока» — «тренировка».
bool typoOf(String a, String b) {
  if (a == b) return false;
  if (nearWords(a, b)) return true;
  if (a.length != b.length) return false;
  final differ = [
    for (var index = 0; index < a.length; index++)
      if (a[index] != b[index]) index,
  ];
  return differ.length == 2 && differ[1] == differ[0] + 1 && a[differ[0]] == b[differ[1]] && a[differ[1]] == b[differ[0]];
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
