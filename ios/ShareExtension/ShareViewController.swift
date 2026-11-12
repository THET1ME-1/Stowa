import UIKit
import UniformTypeIdentifiers

/// Окно «Поделиться»: складывает присланное в папку группы и открывает Stowa.
class ShareViewController: UIViewController {
  private var started = false

  /// Присланное в порядке вложений; что не прочиталось — nil.
  private var pieces: [[String: String]?] = []

  /// Идентификатор приложения: свой без последнего слова.
  private var appId: String {
    return (Bundle.main.bundleIdentifier ?? "").split(separator: ".").dropLast().joined(separator: ".")
  }

  private var groupId: String {
    return (Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String) ?? "group.\(appId)"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if started { return }
    started = true
    collect()
  }

  private func collect() {
    let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
    let providers = items.flatMap { $0.attachments ?? [] }
    let message = items.first?.attributedContentText?.string
    let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)?.appendingPathComponent("shared")
    // прошлое присланное приложение уже забрало, от него остались пустые папки
    if let folder = folder { try? FileManager.default.removeItem(at: folder) }

    pieces = Array(repeating: nil, count: providers.count)
    // файл раньше ссылки: адрес файла — тоже ссылка
    let kinds: [UTType] = [.image, .movie, .fileURL, .url, .text, .data]
    let waiting = DispatchGroup()
    for (index, provider) in providers.enumerated() {
      guard let kind = kinds.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else { continue }
      let name = provider.suggestedName ?? "file"
      let fileExtension = provider.registeredTypeIdentifiers.compactMap { UTType($0) }.first(where: { $0.conforms(to: kind) })?.preferredFilenameExtension
      waiting.enter()
      provider.loadItem(forTypeIdentifier: kind.identifier, options: nil) { value, _ in
        let piece = sharedPiece(from: value, kind: kind, name: name, fileExtension: fileExtension, folder: folder)
        DispatchQueue.main.async {
          self.pieces[index] = piece
          waiting.leave()
        }
      }
    }
    waiting.notify(queue: .main) {
      self.finish(message: message)
    }
  }

  /// Отдаёт список приложению тем же путём, что и расширение плагина: общие настройки и ссылка.
  private func finish(message: String?) {
    let ready = pieces.compactMap { $0 }
    if !ready.isEmpty, let data = try? JSONSerialization.data(withJSONObject: ready), let link = URL(string: "ShareMedia-\(appId):share") {
      let defaults = UserDefaults(suiteName: groupId)
      defaults?.set(data, forKey: "ShareKey")
      defaults?.set(message, forKey: "ShareMessageKey")
      defaults?.synchronize()
      openApp(link)
    }
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  /// У расширения нет своего приложения: до него идём по цепочке ответчиков.
  private func openApp(_ link: URL) {
    // прямой вызов open в расширении не собирается: метод зовём по имени
    typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
    let modern = sel_registerName("openURL:options:completionHandler:")
    let legacy = sel_registerName("openURL:")
    var responder: UIResponder? = self
    while let current = responder {
      if #available(iOS 18.0, *) {
        if current is UIApplication, current.responds(to: modern), let implementation = current.method(for: modern) {
          let open = unsafeBitCast(implementation, to: Open.self)
          open(current, modern, link as NSURL, NSDictionary(), nil)
        }
      } else if current.responds(to: legacy) {
        _ = current.perform(legacy, with: link)
      }
      responder = current.next
    }
  }
}

/// Одно присланное так, как его читает приложение: путь, вид и MIME.
private func sharedPiece(from value: NSSecureCoding?, kind: UTType, name: String, fileExtension: String?, folder: URL?) -> [String: String]? {
  if let text = value as? String {
    return ["path": text, "type": kind == .url ? "url" : "text"]
  }
  if let url = value as? URL, !url.isFileURL {
    return ["path": url.absoluteString, "type": "url"]
  }
  guard let folder = folder else { return nil }
  // своя папка на каждый файл: одинаковые имена не сталкиваются
  let spot = folder.appendingPathComponent(UUID().uuidString)
  guard let target = try? storedCopy(of: value, name: name, fileExtension: fileExtension, in: spot) else { return nil }

  let type = UTType(filenameExtension: target.pathExtension) ?? kind
  var piece = ["path": "file://" + target.path, "type": "file"]
  if type.conforms(to: .image) {
    piece["type"] = "image"
  } else if type.conforms(to: .movie) {
    piece["type"] = "video"
  }
  if let mime = type.preferredMIMEType { piece["mimeType"] = mime }
  return piece
}

/// Кладёт файл, картинку или данные в [spot]; чего не понял — nil.
private func storedCopy(of value: NSSecureCoding?, name: String, fileExtension: String?, in spot: URL) throws -> URL? {
  try FileManager.default.createDirectory(at: spot, withIntermediateDirectories: true, attributes: nil)
  if let url = value as? URL {
    let target = spot.appendingPathComponent(url.lastPathComponent)
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    try FileManager.default.copyItem(at: url, to: target)
    return target
  }
  let base = (name as NSString).deletingPathExtension
  if let image = value as? UIImage {
    // PNG не хранит поворот: повёрнутый снимок уходит в JPEG
    let upright = image.imageOrientation == .up
    guard let data = upright ? image.pngData() : image.jpegData(compressionQuality: 0.95) else { return nil }
    let target = spot.appendingPathComponent(base + (upright ? ".png" : ".jpg"))
    try data.write(to: target)
    return target
  }
  if let data = value as? Data {
    let named = (name as NSString).pathExtension.isEmpty && fileExtension != nil ? "\(name).\(fileExtension ?? "")" : name
    let target = spot.appendingPathComponent(named)
    try data.write(to: target)
    return target
  }
  return nil
}
