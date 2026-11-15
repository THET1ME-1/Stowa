import Foundation

/// Подписи виджетов на языках Stowa. Строка — те же слова, что у виджета Android
/// (res/values-*/strings.xml). Без своих таблиц: этот файл собирает и стенд раскладки.
enum Texts {
  /// Язык телефона из тех, что знает Stowa; остальные — по-английски.
  static var language: String {
    let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
    return ["ru", "uk", "de", "es", "pl", "ro"].contains(code) ? code : "en"
  }

  private static func pick(_ values: [String: String]) -> String { values[language] ?? values["en"] ?? "" }

  static var hint: String {
    pick([
      "ru": "Закинь что угодно", "uk": "Закинь що завгодно", "de": "Wirf irgendwas rein",
      "es": "Suelta lo que sea", "pl": "Wrzuć cokolwiek", "ro": "Aruncă orice", "en": "Drop anything",
    ])
  }

  static var photo: String {
    pick(["ru": "Фото", "uk": "Фото", "de": "Foto", "es": "Foto", "pl": "Zdjęcie", "ro": "Fotografie", "en": "Photo"])
  }

  static var voice: String {
    pick([
      "ru": "Голосовое", "uk": "Голосове", "de": "Sprachnotiz", "es": "Nota de voz", "pl": "Głosówka",
      "ro": "Mesaj vocal", "en": "Voice note",
    ])
  }

  static var composerName: String {
    pick([
      "ru": "Строка Stowa", "uk": "Рядок Stowa", "de": "Stowa-Zeile", "es": "Línea de Stowa",
      "pl": "Linia Stowa", "ro": "Linia Stowa", "en": "Stowa line",
    ])
  }

  static var composerDescription: String {
    pick([
      "ru": "Закинуть мысль, ссылку или голосовое, не открывая главную",
      "uk": "Закинути думку, посилання чи голосове, не відкриваючи головну",
      "de": "Gedanken, Link oder Sprachnotiz speichern, ohne die App zu öffnen",
      "es": "Guarda una idea, un enlace o una nota de voz sin abrir la app",
      "pl": "Zapisz myśl, link lub głosówkę bez otwierania aplikacji",
      "ro": "Salvează un gând, un link sau o notă vocală fără să deschizi aplicația",
      "en": "Save a thought, link or voice note without opening the app",
    ])
  }

  static var noteName: String {
    pick(["ru": "Заметка", "uk": "Нотатка", "de": "Notiz", "es": "Nota", "pl": "Notatka", "ro": "Notiță", "en": "Note"])
  }

  static var noteDescription: String {
    pick([
      "ru": "Выбранная заметка или случайная, новая каждый день",
      "uk": "Вибрана нотатка або випадкова, нова щодня",
      "de": "Eine gewählte Notiz oder jeden Tag eine zufällige",
      "es": "Una nota elegida o una al azar cada día",
      "pl": "Wybrana notatka albo losowa, nowa każdego dnia",
      "ro": "O notiță aleasă sau una la întâmplare în fiecare zi",
      "en": "A chosen note, or a random one every day",
    ])
  }

  static var locked: String {
    pick([
      "ru": "Stowa под замком", "uk": "Stowa під замком", "de": "Stowa ist gesperrt", "es": "Stowa está bloqueada",
      "pl": "Stowa jest zablokowana", "ro": "Stowa este blocată", "en": "Stowa is locked",
    ])
  }

  static var empty: String {
    pick([
      "ru": "Открой Stowa, и заметки появятся здесь", "uk": "Відкрий Stowa, і нотатки з'являться тут",
      "de": "Öffne Stowa, dann erscheinen hier deine Notizen", "es": "Abre Stowa y aquí aparecerán tus notas",
      "pl": "Otwórz Stowa, a notatki pojawią się tutaj", "ro": "Deschide Stowa și notițele apar aici",
      "en": "Open Stowa and your notes show up here",
    ])
  }

  static var untitled: String {
    pick(["ru": "Без названия", "uk": "Без назви", "de": "Ohne Titel", "es": "Sin título", "pl": "Bez tytułu", "ro": "Fără titlu", "en": "Untitled"])
  }

  /// Пример в галерее виджетов, пока Stowa не писала файл: список покупок.
  static var sample: (title: String, items: [String]) {
    let values: [String: (String, [String])] = [
      "ru": ("Купить", ["молоко", "хлеб", "сыр"]), "uk": ("Купити", ["молоко", "хліб", "сир"]),
      "de": ("Einkaufen", ["Milch", "Brot", "Käse"]), "es": ("Compras", ["leche", "pan", "queso"]),
      "pl": ("Zakupy", ["mleko", "chleb", "ser"]), "ro": ("Cumpărături", ["lapte", "pâine", "brânză"]),
      "en": ("Groceries", ["milk", "bread", "cheese"]),
    ]
    let pair = values[language] ?? values["en"]!
    return (pair.0, pair.1)
  }

  /// «ещё 3» под обрезанным списком.
  static func more(_ count: Int) -> String {
    pick(["ru": "ещё \(count)", "uk": "ще \(count)", "de": "noch \(count)", "es": "\(count) más", "pl": "jeszcze \(count)", "ro": "încă \(count)", "en": "\(count) more"])
  }
}
