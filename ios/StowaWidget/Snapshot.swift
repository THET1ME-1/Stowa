import Foundation

/// Заметка из `widget.json`. Файл пишет приложение (lib/services/widget_snapshot.dart):
/// без корзины, скрытых папок и пометки 18+; под «Кодом на вход» заметок нет.
struct WidgetNote: Codable, Hashable, Identifiable {
  struct Line: Codable, Hashable {
    let text: String
    /// Пункт списка: отмечен или нет. Обычная строка — nil.
    let done: Bool?
  }

  let id: String
  let title: String
  let lines: [Line]
  /// Цвет папки ARGB; без папки — nil.
  let color: UInt32?
  let pinned: Bool
}

struct WidgetSnapshot: Codable {
  let version: Int
  let locked: Bool
  let notes: [WidgetNote]

  static let groupId = "group.app.stowa"

  /// Файл ещё не писали (виджет поставили до первого открытия Stowa) — nil.
  static func load() -> WidgetSnapshot? {
    guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId),
      let data = try? Data(contentsOf: folder.appendingPathComponent("widget.json"))
    else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }
}

/// Что показывает виджет заметки.
enum NoteState: Hashable {
  case note(WidgetNote)
  /// «Код на вход» включён.
  case locked
  /// Файла нет или заметок нет.
  case empty
}

/// Случайная заметка дня: весь день одна и та же, «другая» сдвигает выбор на [shift].
enum DailyPick {
  static func pick(_ notes: [WidgetNote], day: Date, shift: Int, calendar: Calendar = .current) -> WidgetNote? {
    guard !notes.isEmpty else { return nil }
    let start = calendar.startOfDay(for: day)
    let days = Int64(calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: start).day ?? 0)
    // соседние дни разбросаны по списку, а не идут подряд
    let mixed = UInt64(bitPattern: days) &* 2_654_435_761 &+ UInt64(bitPattern: Int64(shift))
    return notes[Int(mixed % UInt64(notes.count))]
  }
}

/// Ссылки, которыми виджеты открывают Stowa. Разбирает их ios/Runner/LaunchChannel.swift.
enum StowaLink {
  static let compose = URL(string: "stowa://compose")!
  static let voice = URL(string: "stowa://voice")!
  static let camera = URL(string: "stowa://camera")!
  static let home = URL(string: "stowa://home")!

  static func note(_ id: String) -> URL {
    var parts = URLComponents()
    parts.scheme = "stowa"
    parts.host = "open"
    parts.queryItems = [URLQueryItem(name: "payload", value: "note:\(id)")]
    return parts.url ?? home
  }
}
