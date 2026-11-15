// Рисует виды виджетов iPhone в картинки, чтобы посмотреть раскладку без телефона.
// Собирается из настоящих файлов ios/StowaWidget/ (виды, цвета, подписи) — см. run.sh.
// Только macOS: SwiftUI на Linux нет. Прогон — .github/workflows/ios-widget-layout.yml.
import AppKit
import SwiftUI

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
var failures = 0

/// Размеры iPhone 15 Pro в точках: виджет главного экрана и экрана блокировки.
enum Frame {
  static let small = CGSize(width: 170, height: 170)
  static let medium = CGSize(width: 364, height: 170)
  static let large = CGSize(width: 364, height: 382)
  static let lockRect = CGSize(width: 172, height: 76)
  static let lockCircle = CGSize(width: 76, height: 76)
  static let lockInline = CGSize(width: 260, height: 26)
}

func line(_ text: String, _ done: Bool? = nil) -> WidgetNote.Line { WidgetNote.Line(text: text, done: done) }

let shopping = WidgetNote(
  id: "buy", title: "Купить",
  lines: [line("молоко", false), line("хлеб", true), line("сыр", false), line("яйца десяток", false), line("кофе в зёрнах", false)],
  color: 0xFFFE_C766, pinned: true
)
let long = WidgetNote(
  id: "long", title: "Длинное название заметки, которое никак не помещается в одну строку виджета",
  lines: (1...12).map { line("Строка заметки номер \($0), довольно длинная, чтобы проверить перенос") },
  color: 0xFF5F_CDF5, pinned: false
)
let plain = WidgetNote(
  id: "plain", title: "Пароль от Wi‑Fi на даче",
  lines: [line("сеть Dacha_5G"), line("qwerty12345")],
  color: nil, pinned: false
)
let titleOnly = WidgetNote(id: "title", title: "Позвонить маме в воскресенье вечером", lines: [], color: 0xFFBC_B1FF, pinned: false)

/// Виджет главного экрана: подложка со скруглением и поля системы.
func homeWidget<V: View, B: View>(_ content: V, background: B) -> some View {
  content
    .padding(16)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
}

/// Экран блокировки рисует виджет белым поверх обоев.
func lockWidget<V: View>(_ content: V, circle: Bool = false) -> some View {
  content
    .foregroundStyle(.white)
    .padding(circle ? 0 : 4)
    .background(circle ? AnyView(Circle().fill(.white.opacity(0.18))) : AnyView(Color.clear))
}

@MainActor
func render<V: View>(_ name: String, _ view: V, _ size: CGSize, scheme: ColorScheme, wallpaper: Color) {
  let canvas = ZStack {
    wallpaper
    view.frame(width: size.width, height: size.height)
  }
  .frame(width: size.width + 24, height: size.height + 24)
  .environment(\.colorScheme, scheme)
  let renderer = ImageRenderer(content: canvas)
  renderer.scale = 2
  guard let image = renderer.cgImage else {
    print("✗ \(name): картинка не собралась")
    failures += 1
    return
  }
  let rep = NSBitmapImageRep(cgImage: image)
  let file = "\(out)/\(name).png"
  do {
    try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: file))
    print("✓ \(name) \(image.width)×\(image.height)")
  } catch {
    print("✗ \(name): не записалась (\(error))")
    failures += 1
  }
}

MainActor.assumeIsolated {
  for scheme in [ColorScheme.dark, .light] {
    let palette = StowaPalette.of(scheme)
    let tag = scheme == .dark ? "dark" : "light"
    let home = scheme == .dark ? Color(white: 0.08) : Color(white: 0.82)

    render("composer_medium_\(tag)", homeWidget(ComposerMedium(palette: palette), background: Color(argb: palette.background)), Frame.medium, scheme: scheme, wallpaper: home)

    let notes: [(String, NoteState, Bool)] = [
      ("list", .note(shopping), false), ("long", .note(long), true), ("plain", .note(plain), false),
      ("title", .note(titleOnly), true), ("locked", .locked, false), ("empty", .empty, false),
    ]
    for (name, state, random) in notes {
      for (size, frame, label) in [(NoteSize.small, Frame.small, "small"), (.medium, Frame.medium, "medium"), (.large, Frame.large, "large")] {
        let card = NoteCard(state: state, size: size, random: random, palette: palette)
        render("note_\(name)_\(label)_\(tag)", homeWidget(card, background: NoteBackground(state: state, palette: palette)), frame, scheme: scheme, wallpaper: home)
      }
    }
  }

  // экран блокировки один на обе темы: система красит виджеты сама
  let wall = Color(red: 0.16, green: 0.2, blue: 0.32)
  render("lock_composer_line", lockWidget(ComposerLockLine()), Frame.lockRect, scheme: .dark, wallpaper: wall)
  render("lock_composer_mic", lockWidget(ComposerLockMic(), circle: true), Frame.lockCircle, scheme: .dark, wallpaper: wall)
  for (name, state) in [("list", NoteState.note(shopping)), ("long", .note(long)), ("locked", .locked), ("empty", .empty)] {
    render("lock_note_\(name)", lockWidget(NoteLockCard(state: state)), Frame.lockRect, scheme: .dark, wallpaper: wall)
    render("lock_inline_\(name)", lockWidget(NoteLockInline(state: state)), Frame.lockInline, scheme: .dark, wallpaper: wall)
  }
}

// случайная заметка дня: весь день одна, «другая» и следующий день — другая
let notes = [shopping, long, plain, titleOnly]
let day = Date(timeIntervalSince1970: 1_794_700_000)
let first = DailyPick.pick(notes, day: day, shift: 0)
let sameDay = DailyPick.pick(notes, day: day.addingTimeInterval(3600), shift: 0)
let shifted = DailyPick.pick(notes, day: day, shift: 1)
let check: [(Bool, String)] = [
  (first == sameDay, "в течение дня заметка та же"),
  (first != shifted, "«другая» меняет заметку"),
  (DailyPick.pick([], day: day, shift: 0) == nil, "без заметок — пусто"),
  (StowaLink.note("a b").absoluteString == "stowa://open?payload=note:a%20b", "ссылка заметки: \(StowaLink.note("a b").absoluteString)"),
]
for (ok, text) in check {
  print(ok ? "✓ \(text)" : "✗ \(text)")
  if !ok { failures += 1 }
}

print(failures == 0 ? "ИТОГ: всё собралось" : "ИТОГ: провалов \(failures)")
exit(failures == 0 ? 0 : 1)
