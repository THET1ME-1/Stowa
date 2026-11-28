// Правила тревог у места без симулятора: собирается вместе с ios/Runner/PlaceRules.swift.
// Запуск (macOS): swiftc ios/Runner/PlaceRules.swift tool/ios_tests/place_rules/main.swift -o /tmp/place_rules && /tmp/place_rules
import Foundation

var failures = 0

func check(_ condition: Bool, _ what: String) {
  print(condition ? "ок   \(what)" : "СБОЙ \(what)")
  if !condition { failures += 1 }
}

func alarm(_ id: String, _ latitude: Double, _ longitude: Double, budget: Bool = false, radius: Double = 150) -> PlaceAlarm {
  PlaceAlarm(["id": id, "title": id, "body": "", "payload": "note:\(id)", "latitude": latitude, "longitude": longitude, "radius": radius, "budget": budget])!
}

// одно напоминание на два магазина: ключ общий
check(PlaceRules.noteKey("note:42@shop1") == "note:42", "«note:42@shop1» и «note:42» — одно напоминание")
check(PlaceRules.noteKey("note:42") == "note:42", "ключ без магазина — сам id")

// Кишинёв: центр и точка в ~1,1 км
let center = (latitude: 47.0245, longitude: 28.8323)
let distance = PlaceRules.distance(47.0245, 28.8323, 47.0345, 28.8323)
check(abs(distance - 1112) < 5, "градус широты по 0,01 — около 1112 м (вышло \(Int(distance)))")

// сработавшее своё не следим, покупки следим всегда
let watched = PlaceRules.watched([alarm("note:1", 47, 28), alarm("note:2@a", 47, 28), alarm("shop:a", 47, 28, budget: true)], fired: ["note:2@b"], here: nil)
check(watched.map(\.id) == ["note:1", "shop:a"], "сработавшее напоминание снимается со всех магазинов, покупки остаются")

// мест больше лимита — ближайшие к телефону
var many: [PlaceAlarm] = []
for index in 0..<30 { many.append(alarm("note:\(index)", center.latitude + Double(index) * 0.01, center.longitude)) }
let nearest = PlaceRules.watched(many.reversed(), fired: [], here: center)
check(nearest.count == PlaceRules.watchLimit, "следим не больше чем за \(PlaceRules.watchLimit)")
check(Set(nearest.map(\.id)) == Set((0..<PlaceRules.watchLimit).map { "note:\($0)" }), "берутся ближайшие")

// внутри круга при постановке — ждём выхода; маленький круг считается не меньше 100 м
check(PlaceRules.inside(alarm("x", 47.0245, 28.8323), here: center), "телефон в центре круга — внутри")
check(PlaceRules.inside(alarm("x", 47.0253, 28.8323, radius: 50), here: center), "в 90 м от круга в 50 м — внутри: меньше 100 м не ставим")
check(!PlaceRules.inside(alarm("x", 47.0345, 28.8323), here: center), "в километре — снаружи")
check(!PlaceRules.inside(alarm("x", 47.0245, 28.8323), here: nil), "где телефон, неизвестно — снаружи")

// звенеть: своё один раз, покупки раз в день
check(PlaceRules.shouldFire(alarm("note:1@a", 0, 0), fired: [], budgetDay: nil, today: "2026-11-28"), "новое напоминание звенит")
check(!PlaceRules.shouldFire(alarm("note:1@a", 0, 0), fired: ["note:1@b"], budgetDay: nil, today: "2026-11-28"), "у второго магазина того же напоминания — тишина")
check(PlaceRules.shouldFire(alarm("shop:a", 0, 0, budget: true), fired: ["shop:a"], budgetDay: "2026-11-27", today: "2026-11-28"), "покупки: вчерашний бюджет не мешает")
check(!PlaceRules.shouldFire(alarm("shop:a", 0, 0, budget: true), fired: [], budgetDay: "2026-11-28", today: "2026-11-28"), "покупки: сегодня возвращающее уже было")

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Chisinau")!
check(PlaceRules.dayKey(Date(timeIntervalSince1970: 1_793_000_000), calendar: calendar) == "2026-10-26", "день бюджета в виде 2026-10-26")

print(failures == 0 ? "ИТОГ: все проверки прошли" : "ИТОГ: сбоев \(failures)")
exit(failures == 0 ? 0 : 1)
