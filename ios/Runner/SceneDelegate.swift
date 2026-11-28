import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// Канал `stowa/window` iPhone: Dart говорит, прятать ли экран при уходе (замок на вход или
/// открытые скрытые папки, lib/features/privacy/privacy_gate.dart).
///
/// Снимок для переключателя приложений система делает сразу при уходе, а Flutter свою заставку
/// дорисовать не успевает: прячет экран сам Swift, по событиям сцены.
final class WindowGuard {
  private static let shared = WindowGuard()

  private var guarding = false
  private var cover: UIView?

  static func register(_ registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "StowaWindow")?.messenger() else { return }
    let channel = FlutterMethodChannel(name: "stowa/window", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "guard" else {
        result(FlutterMethodNotImplemented)
        return
      }
      shared.guarding = call.arguments as? Bool ?? false
      result(nil)
    }
    let center = NotificationCenter.default
    center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { note in
      shared.hide(note.object as? UIWindowScene)
    }
    center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { _ in
      shared.show()
    }
  }

  private func hide(_ scene: UIWindowScene?) {
    guard guarding, cover == nil, let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first else { return }
    let view = WindowGuard.coverView(frame: window.bounds)
    window.addSubview(view)
    cover = view
  }

  private func show() {
    cover?.removeFromSuperview()
    cover = nil
  }

  /// Заставка как у Flutter (`_Cover`): фон приложения и замок посередине.
  private static func coverView(frame: CGRect) -> UIView {
    let view = UIView(frame: frame)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.backgroundColor = UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 0x14 / 255, green: 0x15 / 255, blue: 0x17 / 255, alpha: 1)
        : UIColor(red: 0xF6 / 255, green: 0xF6 / 255, blue: 0xF4 / 255, alpha: 1)
    }
    let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
    lock.tintColor = .secondaryLabel
    lock.contentMode = .scaleAspectFit
    lock.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(lock)
    NSLayoutConstraint.activate([
      lock.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      lock.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      lock.widthAnchor.constraint(equalToConstant: 34),
      lock.heightAnchor.constraint(equalToConstant: 40),
    ])
    return view
  }
}
