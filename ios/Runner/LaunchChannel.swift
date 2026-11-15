import Flutter
import UIKit

/// Канал `stowa/launch`: с чем Stowa открыли снаружи. Пара к MainActivity.kt.
///
/// Виджеты открывают приложение ссылками: `stowa://compose`, `stowa://voice`, `stowa://camera`
/// и `stowa://open?payload=note:<id>`. Dart спрашивает `initial` при запуске, а ссылки в уже
/// открытое приложение получает через `open` — тем же текстом, что на Android.
///
/// Регистрируется раньше плагинов: плагин «Поделиться» на любую ссылку при запуске отвечает
/// «разобрал», и тем, кто после него, Flutter может отдать пустые параметры сцены.
final class LaunchChannel: NSObject, FlutterSceneLifeCycleDelegate {
  /// Обработчик живёт, пока живёт приложение: реестр держит его слабо.
  private static var shared: LaunchChannel?

  private var channel: FlutterMethodChannel?

  /// Ссылка, с которой открыли, пока Dart её не спросил.
  private var pending: String?

  static func register(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "StowaLaunch") else { return }
    let launch = LaunchChannel()
    let channel = FlutterMethodChannel(name: "stowa/launch", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "initial" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(launch.pending)
      launch.pending = nil
    }
    launch.channel = channel
    registrar.addSceneDelegate(launch)
    shared = launch
  }

  // холодный старт ссылкой: запомнить до вопроса Dart; разобранной не считать — дальше плагины
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    for context in connectionOptions?.urlContexts ?? [] {
      if let action = LaunchChannel.action(of: context.url) { pending = action }
    }
    return false
  }

  // приложение уже открыто: сразу в Dart
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts {
      guard let action = LaunchChannel.action(of: context.url) else { continue }
      channel?.invokeMethod("open", arguments: action)
      handled = true
    }
    return handled
  }

  /// `stowa://open?payload=note:42` → `open:note:42`, `stowa://voice` → `voice`. Чужая ссылка — nil.
  static func action(of url: URL) -> String? {
    guard url.scheme == "stowa", let host = url.host, !host.isEmpty else { return nil }
    guard host == "open" else { return host }
    let payload = URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "payload" })?.value
    return payload.map { "open:\($0)" }
  }
}
