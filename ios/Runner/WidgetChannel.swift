import Flutter
import WidgetKit

/// Канал `stowa/widget`: `write` кладёт `widget.json` в папку группы и просит виджеты
/// перерисоваться. Текст файла собирает Dart (lib/services/widget_snapshot.dart), виджеты
/// читают его в ios/StowaWidget/Snapshot.swift.
enum WidgetChannel {
  static let groupId = "group.app.stowa"

  static func register(_ registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "StowaWidget")?.messenger() else { return }
    let channel = FlutterMethodChannel(name: "stowa/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "write", let text = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
        result(FlutterError(code: "no-group", message: "папки группы нет", details: nil))
        return
      }
      do {
        // целиком и разом: виджет не должен прочитать недописанный файл
        try Data(text.utf8).write(to: folder.appendingPathComponent("widget.json"), options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } catch {
        result(FlutterError(code: "write", message: error.localizedDescription, details: nil))
      }
    }
  }
}
