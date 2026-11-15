import SwiftUI

/// Цвета Stowa для виджетов — те же, что `StowaPalette.graphiteDark` и `graphiteLight`
/// (lib/core/theme/palette.dart). Тема виджета — тема телефона.
struct StowaPalette {
  let background: UInt32
  let container: UInt32
  let containerHigh: UInt32
  let onSurface: UInt32
  let onSurfaceVariant: UInt32
  let muted: UInt32
  let accent: UInt32
  let onAccent: UInt32

  static let dark = StowaPalette(
    background: 0xFF14_1517, container: 0xFF1F_2023, containerHigh: 0xFF26_272B, onSurface: 0xFFF2_F2F0,
    onSurfaceVariant: 0xFFB0_B1B6, muted: 0xFF96_979D, accent: 0xFFF4_F4F2, onAccent: 0xFF14_1517
  )

  static let light = StowaPalette(
    background: 0xFFF6_F6F4, container: 0xFFEA_EAE7, containerHigh: 0xFFE4_E4E1, onSurface: 0xFF1B_1C1E,
    onSurfaceVariant: 0xFF46_474C, muted: 0xFF5F_6066, accent: 0xFF1B_1C1E, onAccent: 0xFFF6_F6F4
  )

  static func of(_ scheme: ColorScheme) -> StowaPalette { scheme == .dark ? dark : light }

  /// Подложка заметки в цвет её папки: 16 % цвета поверх контейнера, как `FolderPalette.tint`.
  func tint(_ color: UInt32?) -> Color {
    guard let color else { return Color(argb: container) }
    return Color(argb: blend(color, 0.16, over: container))
  }
}

extension Color {
  init(argb: UInt32) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double((argb >> 24) & 0xFF) / 255
    )
  }
}

/// [top] с прозрачностью [strength] поверх непрозрачного [bottom].
func blend(_ top: UInt32, _ strength: Double, over bottom: UInt32) -> UInt32 {
  func channel(_ shift: UInt32) -> UInt32 {
    let upper = Double((top >> shift) & 0xFF)
    let lower = Double((bottom >> shift) & 0xFF)
    return UInt32((upper * strength + lower * (1 - strength)).rounded()) << shift
  }
  return 0xFF00_0000 | channel(16) | channel(8) | channel(0)
}
