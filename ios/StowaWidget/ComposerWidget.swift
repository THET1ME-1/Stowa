import SwiftUI
import WidgetKit

/// Виджет-строка: данных не показывает, поэтому одна запись и никаких обновлений.
struct ComposerEntry: TimelineEntry {
  let date: Date
}

struct ComposerProvider: TimelineProvider {
  func placeholder(in context: Context) -> ComposerEntry { ComposerEntry(date: .now) }

  func getSnapshot(in context: Context, completion: @escaping (ComposerEntry) -> Void) {
    completion(ComposerEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ComposerEntry>) -> Void) {
    completion(Timeline(entries: [ComposerEntry(date: .now)], policy: .never))
  }
}

struct ComposerWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    let palette = StowaPalette.of(scheme)
    switch family {
    case .accessoryCircular:
      ComposerLockMic()
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        .widgetURL(StowaLink.voice)
    case .accessoryRectangular:
      ComposerLockLine()
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(StowaLink.compose)
    default:
      ComposerMedium(palette: palette)
        .containerBackground(for: .widget) { Color(argb: palette.background) }
        .widgetURL(StowaLink.compose)
    }
  }
}

struct ComposerWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "app.stowa.composer", provider: ComposerProvider()) { _ in
      ComposerWidgetView()
    }
    .configurationDisplayName(Texts.composerName)
    .description(Texts.composerDescription)
    .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryCircular])
  }
}
