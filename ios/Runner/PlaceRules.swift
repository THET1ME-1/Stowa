import Foundation

/// Тревога у места, как её прислал Dart (`PlaceAlarm.toJson` в lib/services/place_channel.dart).
/// Текст готов заранее: уведомление показывает Swift, Dart при выгруженном приложении не живёт.
struct PlaceAlarm: Equatable {
  let id: String
  let title: String
  let body: String
  let payload: String
  let latitude: Double
  let longitude: Double
  let radius: Double
  /// Возвращающее (покупки у магазина): одно в день на всех, в общем бюджете дня.
  let budget: Bool

  init?(_ json: [String: Any]) {
    guard let id = json["id"] as? String,
      let latitude = (json["latitude"] as? NSNumber)?.doubleValue,
      let longitude = (json["longitude"] as? NSNumber)?.doubleValue
    else { return nil }
    self.id = id
    title = json["title"] as? String ?? ""
    body = json["body"] as? String ?? ""
    payload = json["payload"] as? String ?? id
    self.latitude = latitude
    self.longitude = longitude
    radius = (json["radius"] as? NSNumber)?.doubleValue ?? 150
    budget = json["budget"] as? Bool ?? false
  }
}

/// Правила тревог без системы: что следить, когда звенеть. Пара к PlaceAlarms.kt.
/// Проверяются `tool/ios_tests/place_rules/main.swift` в ios.yml.
enum PlaceRules {
  /// iPhone следит не больше чем за 20 кругами на приложение: один держим под «я сдвинулся».
  static let watchLimit = 19

  /// Круг меньше 100 м система ловит плохо: ставим не меньше.
  static let minRadius = 100.0

  /// «note:<id>@<магазин>» и «note:<id>» — одно напоминание.
  static func noteKey(_ id: String) -> String {
    guard let at = id.firstIndex(of: "@") else { return id }
    return String(id[..<at])
  }

  /// Расстояние по поверхности Земли в метрах.
  static func distance(_ latitude1: Double, _ longitude1: Double, _ latitude2: Double, _ longitude2: Double) -> Double {
    let radians = Double.pi / 180
    let dLatitude = (latitude2 - latitude1) * radians
    let dLongitude = (longitude2 - longitude1) * radians
    let a = sin(dLatitude / 2) * sin(dLatitude / 2)
      + cos(latitude1 * radians) * cos(latitude2 * radians) * sin(dLongitude / 2) * sin(dLongitude / 2)
    return 6_371_000 * 2 * atan2(sqrt(a), sqrt(1 - a))
  }

  /// За чем следить сейчас: своё напоминание срабатывает один раз, покупки — каждый день.
  /// Тревог больше, чем мест у системы, — ближайшие к телефону; где телефон, неизвестно — первые.
  static func watched(_ alarms: [PlaceAlarm], fired: [String], here: (latitude: Double, longitude: Double)?, limit: Int = watchLimit) -> [PlaceAlarm] {
    let firedKeys = Set(fired.map(noteKey))
    let waiting = alarms.filter { $0.budget || !firedKeys.contains(noteKey($0.id)) }
    guard waiting.count > limit, let here else { return Array(waiting.prefix(limit)) }
    return Array(
      waiting
        .sorted { distance(here.latitude, here.longitude, $0.latitude, $0.longitude) < distance(here.latitude, here.longitude, $1.latitude, $1.longitude) }
        .prefix(limit))
  }

  /// Телефон уже внутри круга: «когда буду здесь» значит в следующий приход, ждём выхода.
  static func inside(_ alarm: PlaceAlarm, here: (latitude: Double, longitude: Double)?) -> Bool {
    guard let here else { return false }
    return distance(here.latitude, here.longitude, alarm.latitude, alarm.longitude) < max(alarm.radius, minRadius)
  }

  /// Звенеть ли при входе: своё — если ещё не звенело, покупки — если сегодня возвращающего не было.
  static func shouldFire(_ alarm: PlaceAlarm, fired: [String], budgetDay: String?, today: String) -> Bool {
    if alarm.budget { return budgetDay != today }
    return !fired.contains { noteKey($0) == noteKey(alarm.id) }
  }

  /// День бюджета «2026-11-06» — тот же, что пишет Dart (`returnDayKey`).
  static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
