import CoreLocation
import Flutter
import UIKit
import UserNotifications

/// Напоминания у места на iPhone: круги CLLocationManager. Пара к PlaceAlarms.kt.
///
/// Система будит выгруженное приложение при входе в круг, если менеджер с делегатом создан при
/// запуске (`start` из AppDelegate). Текст уведомления Dart готовит заранее и присылает в `sync`,
/// здесь он только показывается. Сработавшее кладётся в общие настройки Flutter
/// (`flutter.place_fired`): их читает Dart и в приложении, и в фоновой задаче.
///
/// Имени сети Wi-Fi iPhone в фоне не отдаёт: дом и работа узнаются только по кругу.
final class PlaceAlarms: NSObject, CLLocationManagerDelegate {
  static let shared = PlaceAlarms()

  /// Начало адреса своих кругов и уведомлений: чужое (если появится) не трогаем.
  static let prefix = "stowa-place:"

  private let manager = CLLocationManager()
  private let defaults = UserDefaults.standard

  // свои ключи; ключи с `flutter.` — общие с shared_preferences Dart
  private let alarmsKey = "stowa.places.alarms"
  private let insideKey = "stowa.places.inside"
  private let askedKey = "stowa.places.askedAlways"
  private let firedKey = "flutter.place_fired"
  private let budgetKey = "flutter.return_day"

  private override init() {
    super.init()
    manager.delegate = self
  }

  /// Из AppDelegate при каждом запуске: в том числе когда система разбудила приложение у круга.
  /// Круги здесь не переставляются: пересчёт «я уже внутри» съел бы тот самый вход, ради
  /// которого система приложение и разбудила. Достаточно, что менеджер с делегатом создан.
  func start() {}

  // MARK: канал stowa/places

  static func register(_ registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "StowaPlaces")?.messenger() else { return }
    let channel = FlutterMethodChannel(name: "stowa/places", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let places = PlaceAlarms.shared
      switch call.method {
      case "hasBackground":
        result(places.status == .authorizedAlways)
      case "askBackground":
        places.askAlways()
        result(nil)
      case "currentWifi":
        result(nil)
      case "sync":
        let arguments = call.arguments as? [String: Any]
        places.save(arguments?["alarms"] as? [[String: Any]] ?? [])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private var status: CLAuthorizationStatus {
    if #available(iOS 14.0, *) { return manager.authorizationStatus }
    return CLLocationManager.authorizationStatus()
  }

  /// Место «всегда» спрашивается по действию человека. Первый раз система сама покажет окно,
  /// второй раз она его уже не покажет — тогда только настройки приложения.
  func askAlways() {
    switch status {
    case .notDetermined:
      defaults.set(true, forKey: askedKey)
      manager.requestAlwaysAuthorization()
    case .authorizedWhenInUse where !defaults.bool(forKey: askedKey):
      defaults.set(true, forKey: askedKey)
      manager.requestAlwaysAuthorization()
    case .authorizedAlways:
      break
    default:
      if let settings = URL(string: UIApplication.openSettingsURLString) {
        DispatchQueue.main.async { UIApplication.shared.open(settings) }
      }
    }
  }

  // MARK: круги

  private func save(_ alarms: [[String: Any]]) {
    if let data = try? JSONSerialization.data(withJSONObject: alarms) {
      defaults.set(data, forKey: alarmsKey)
    }
    apply()
  }

  private var alarms: [PlaceAlarm] {
    guard let data = defaults.data(forKey: alarmsKey),
      let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return list.compactMap(PlaceAlarm.init)
  }

  private var fired: [String] {
    guard let raw = defaults.string(forKey: firedKey), let data = raw.data(using: .utf8),
      let list = try? JSONSerialization.jsonObject(with: data) as? [String]
    else { return [] }
    return list
  }

  private var here: (latitude: Double, longitude: Double)? {
    guard let location = manager.location else { return nil }
    return (location.coordinate.latitude, location.coordinate.longitude)
  }

  /// Поставить круги заново: после `sync`, смены разрешения и заметного переезда.
  func apply() {
    for region in manager.monitoredRegions where region.identifier.hasPrefix(PlaceAlarms.prefix) {
      manager.stopMonitoring(for: region)
    }
    guard status == .authorizedAlways, CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      manager.stopMonitoringSignificantLocationChanges()
      return
    }
    let all = alarms
    let watched = PlaceRules.watched(all, fired: fired, here: here)
    var inside: [String] = []
    for alarm in watched {
      let radius = min(max(alarm.radius, PlaceRules.minRadius), manager.maximumRegionMonitoringDistance)
      let region = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: alarm.latitude, longitude: alarm.longitude),
        radius: radius,
        identifier: PlaceAlarms.prefix + alarm.id)
      region.notifyOnEntry = true
      region.notifyOnExit = true
      manager.startMonitoring(for: region)
      if PlaceRules.inside(alarm, here: here) { inside.append(alarm.id) }
    }
    defaults.set(inside, forKey: insideKey)
    // мест больше, чем кругов: при заметном переезде ближайшие выбираются заново
    if all.count > PlaceRules.watchLimit {
      manager.startMonitoringSignificantLocationChanges()
    } else {
      manager.stopMonitoringSignificantLocationChanges()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    apply()
  }

  // iOS 13 зовёт старый вариант
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if #unavailable(iOS 14.0) { apply() }
  }

  // заметный переезд: переставлять, только если ближайшие стали другими
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let wanted = Set(PlaceRules.watched(alarms, fired: fired, here: here).map { PlaceAlarms.prefix + $0.id })
    let current = Set(manager.monitoredRegions.map(\.identifier).filter { $0.hasPrefix(PlaceAlarms.prefix) })
    if wanted != current { apply() }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard let id = alarmId(region) else { return }
    if (defaults.stringArray(forKey: insideKey) ?? []).contains(id) { return }
    fire(id)
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard let id = alarmId(region) else { return }
    let inside = (defaults.stringArray(forKey: insideKey) ?? []).filter { $0 != id }
    defaults.set(inside, forKey: insideKey)
  }

  private func alarmId(_ region: CLRegion) -> String? {
    guard region.identifier.hasPrefix(PlaceAlarms.prefix) else { return nil }
    return String(region.identifier.dropFirst(PlaceAlarms.prefix.count))
  }

  /// Вход в круг: показать уведомление, если пора, и записать сработавшее для Dart.
  private func fire(_ id: String) {
    guard let alarm = alarms.first(where: { $0.id == id }) else { return }
    let today = PlaceRules.dayKey(Date())
    let firedNow = fired
    guard PlaceRules.shouldFire(alarm, fired: firedNow, budgetDay: defaults.string(forKey: budgetKey), today: today) else { return }
    if alarm.budget {
      defaults.set(today, forKey: budgetKey)
    } else {
      if let data = try? JSONSerialization.data(withJSONObject: firedNow + [id]), let text = String(data: data, encoding: .utf8) {
        defaults.set(text, forKey: firedKey)
      }
      // одно напоминание — одна тревога на все магазины: остальные круги снимаются
      let key = PlaceRules.noteKey(id)
      for region in manager.monitoredRegions {
        if let other = alarmId(region), PlaceRules.noteKey(other) == key { manager.stopMonitoring(for: region) }
      }
    }
    show(alarm)
  }

  private func show(_ alarm: PlaceAlarm) {
    let content = UNMutableNotificationContent()
    content.title = alarm.title
    content.body = alarm.body
    content.sound = .default
    content.threadIdentifier = "stowa.places"
    content.userInfo = ["stowaPayload": alarm.payload]
    let request = UNNotificationRequest(identifier: PlaceAlarms.prefix + alarm.id, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  /// Касание своего уведомления: куда вести, как ссылка `stowa://open?payload=…` на Android.
  static func payload(of response: UNNotificationResponse) -> String? {
    guard response.notification.request.identifier.hasPrefix(prefix) else { return nil }
    return response.notification.request.content.userInfo["stowaPayload"] as? String
  }
}
