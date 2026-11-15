import SwiftUI

/// Строка «Закинь что угодно» с камерой и микрофоном — как виджет-строка Android
/// (res/layout/composer_widget.xml): подложка containerHigh во всю высоту, микрофон белым кругом.
/// Каждая часть ведёт своей ссылкой; касание мимо строки WidgetKit отдаёт `widgetURL` — строку.
struct ComposerPill: View {
  let palette: StowaPalette

  var body: some View {
    HStack(spacing: 4) {
      Link(destination: StowaLink.compose) {
        Text(Texts.hint)
          .font(.system(size: 16))
          .foregroundStyle(Color(argb: palette.muted))
          .lineLimit(1)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .padding(.leading, 22)
          .contentShape(Rectangle())
      }
      Link(destination: StowaLink.camera) {
        Image(systemName: "camera.fill")
          .font(.system(size: 19, weight: .medium))
          .foregroundStyle(Color(argb: palette.onSurface))
          .frame(width: 48, height: 48)
          .contentShape(Circle())
      }
      .accessibilityLabel(Text(Texts.photo))
      Link(destination: StowaLink.voice) {
        Image(systemName: "mic.fill")
          .font(.system(size: 19, weight: .semibold))
          .foregroundStyle(Color(argb: palette.onAccent))
          .frame(width: 48, height: 48)
          .background(Circle().fill(Color(argb: palette.accent)))
      }
      .accessibilityLabel(Text(Texts.voice))
    }
    .padding(.trailing, 8)
    .frame(height: 64)
    .background(Capsule().fill(Color(argb: palette.containerHigh)))
  }
}

/// Средний виджет на главном экране: имя приложения сверху, строка снизу.
struct ComposerMedium: View {
  let palette: StowaPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Stowa")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Color(argb: palette.onSurface))
        .padding(.leading, 6)
      Spacer(minLength: 8)
      ComposerPill(palette: palette)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// Экран блокировки, прямоугольник: касание открывает строку.
struct ComposerLockLine: View {
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "square.and.pencil")
        .font(.system(size: 18, weight: .semibold))
      Text(Texts.hint)
        .font(.system(size: 15, weight: .semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.85)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// Экран блокировки, круг: касание сразу начинает голосовое.
struct ComposerLockMic: View {
  var body: some View {
    Image(systemName: "mic.fill")
      .font(.system(size: 24, weight: .semibold))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityLabel(Text(Texts.voice))
  }
}
