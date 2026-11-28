import AVFoundation
import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications
import workmanager_apple

/// Фоновые задачи iPhone. Те же имена — в BGTaskSchedulerPermittedIdentifiers Info.plist и
/// `iosBackgroundTasks` в lib/services/background.dart (сверяет ios_background_names_test.dart).
let returnTaskId = "stowa-return"
let processingTaskId = "stowa-ai-queue"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // без делегата iOS не показывает напоминание, пока приложение открыто
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // кнопки уведомлений и фоновые задачи идут в отдельном движке Dart без экрана: плагины
    // и свои каналы в нём надо зарегистрировать, иначе «Готово» нажимается впустую
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback(registerHeadless)
    WorkmanagerPlugin.setPluginRegistrantCallback(registerHeadless)
    // BGTaskScheduler отдаёт задачу, только если обработчик зарегистрирован до конца запуска
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: returnTaskId, frequency: NSNumber(value: 15 * 60))
    WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: processingTaskId)
    // система будит приложение у круга: менеджер мест должен быть на месте сразу
    PlaceAlarms.shared.start()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // ссылки виджетов — раньше плагинов: см. LaunchChannel
    LaunchChannel.register(engineBridge.pluginRegistry)
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupMediaChannel(engineBridge.pluginRegistry)
    WidgetChannel.register(engineBridge.pluginRegistry)
    PlaceAlarms.register(engineBridge.pluginRegistry)
    WindowGuard.register(engineBridge.pluginRegistry)
  }

  // MARK: уведомления, которые показывает сам Swift (напоминания у места)

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard notification.request.identifier.hasPrefix(PlaceAlarms.prefix) else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
      return
    }
    completionHandler([.banner, .list, .sound])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard let payload = PlaceAlarms.payload(of: response) else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
      return
    }
    LaunchChannel.deliver("open:\(payload)")
    completionHandler()
  }
}

/// Движок без экрана (кнопка уведомления, фоновая задача): плагины и канал мест — фон после
/// прихода к месту переставляет круги через него же.
private func registerHeadless(_ registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
  PlaceAlarms.register(registry)
}

extension AppDelegate {

  /// Канал `stowa/media`: длина, размер и кадры своего ролика. Пара к MediaChannel.kt.
  private func setupMediaChannel(_ registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "StowaMedia")?.messenger() else { return }
    let channel = FlutterMethodChannel(name: "stowa/media", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let arguments = call.arguments as? [String: Any], let path = arguments["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      // ролик читается не на главном потоке: длинный файл не должен подвешивать экран
      DispatchQueue.global(qos: .userInitiated).async {
        let answer: Any?
        switch call.method {
        case "probe":
          answer = videoInfo(asset)
        case "frames":
          answer = videoFrames(
            asset,
            moments: arguments["ms"] as? [Int] ?? [],
            outs: arguments["outs"] as? [String] ?? [],
            maxSide: arguments["maxSide"] as? Int ?? 720
          )
        default:
          answer = FlutterMethodNotImplemented
        }
        DispatchQueue.main.async { result(answer) }
      }
    }
  }
}

/// Длина в миллисекундах и размер, как видит человек; ролик не прочитался — nil.
private func videoInfo(_ asset: AVURLAsset) -> [String: Any]? {
  let seconds = CMTimeGetSeconds(asset.duration)
  guard seconds.isFinite, seconds > 0 else { return nil }
  var width = 0
  var height = 0
  // снятое вертикально хранится лёжа с поворотом: размер считается уже повёрнутым
  if let track = asset.tracks(withMediaType: .video).first {
    let size = track.naturalSize.applying(track.preferredTransform)
    width = Int(abs(size.width))
    height = Int(abs(size.height))
  }
  return ["ms": Int(seconds * 1000), "width": width, "height": height]
}

/// Кадры в нужные моменты файлами JPEG; на каждый — записан ли он.
private func videoFrames(_ asset: AVURLAsset, moments: [Int], outs: [String], maxSide: Int) -> [Bool] {
  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true
  generator.maximumSize = CGSize(width: maxSide, height: maxSide)
  // ключевой кадр ближе полсекунды годится: подпись под кадром не соврёт
  let near = CMTime(value: 500, timescale: 1000)
  generator.requestedTimeToleranceBefore = near
  generator.requestedTimeToleranceAfter = near
  return zip(moments, outs).map { moment, out in
    let time = CMTime(value: CMTimeValue(moment), timescale: 1000)
    guard let image = try? generator.copyCGImage(at: time, actualTime: nil),
      let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    else { return false }
    return (try? jpeg.write(to: URL(fileURLWithPath: out))) != nil
  }
}
