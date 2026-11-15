import AppIntents
import SwiftUI
import WidgetKit

/// Заметка в настройке виджета: список берётся из того же `widget.json`.
struct NoteEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "note.entity"
  static var defaultQuery = NoteQuery()

  let id: String
  let title: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(title.isEmpty ? Texts.untitled : title)")
  }
}

struct NoteQuery: EntityQuery {
  private var notes: [NoteEntity] {
    (WidgetSnapshot.load()?.notes ?? []).map { NoteEntity(id: $0.id, title: $0.title) }
  }

  func entities(for identifiers: [NoteEntity.ID]) async throws -> [NoteEntity] {
    notes.filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [NoteEntity] { notes }
}

/// Настройка виджета: какая заметка. Не выбрана — случайная, новая каждый день.
struct PickNoteIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "pick.title"
  static var description = IntentDescription("pick.description")

  @Parameter(title: "pick.note")
  var note: NoteEntity?
}

/// Кнопка «другая» на случайной заметке: сдвинуть выбор дня.
struct ShuffleNoteIntent: AppIntent {
  static var title: LocalizedStringResource = "shuffle.title"
  static let shiftKey = "noteShift"

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: WidgetSnapshot.groupId)
    defaults?.set((defaults?.integer(forKey: ShuffleNoteIntent.shiftKey) ?? 0) + 1, forKey: ShuffleNoteIntent.shiftKey)
    return .result()
  }
}

struct NoteEntry: TimelineEntry {
  let date: Date
  let state: NoteState
  let random: Bool
}

struct NoteProvider: AppIntentTimelineProvider {
  /// Галерея виджетов, пока файла нет: виден пример, а не «открой Stowa».
  private static var sample: NoteEntry {
    let sample = Texts.sample
    let lines = sample.items.enumerated().map { WidgetNote.Line(text: $0.element, done: $0.offset == 1) }
    let note = WidgetNote(id: "sample", title: sample.title, lines: lines, color: 0xFFFE_C766, pinned: true)
    return NoteEntry(date: .now, state: .note(note), random: false)
  }

  func placeholder(in context: Context) -> NoteEntry { NoteProvider.sample }

  func snapshot(for configuration: PickNoteIntent, in context: Context) async -> NoteEntry {
    let entry = entry(for: configuration, at: .now)
    if context.isPreview, case .empty = entry.state { return NoteProvider.sample }
    return entry
  }

  // случайная меняется в полночь; правки заметок приходят сами — приложение зовёт reloadAllTimelines
  func timeline(for configuration: PickNoteIntent, in context: Context) async -> Timeline<NoteEntry> {
    let now = Date()
    let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
    return Timeline(entries: [entry(for: configuration, at: now)], policy: .after(midnight))
  }

  private func entry(for configuration: PickNoteIntent, at date: Date) -> NoteEntry {
    guard let snapshot = WidgetSnapshot.load() else { return NoteEntry(date: date, state: .empty, random: false) }
    if snapshot.locked { return NoteEntry(date: date, state: .locked, random: false) }
    // выбранную удалили или спрятали — показываем случайную, а не пустоту
    if let chosen = configuration.note, let note = snapshot.notes.first(where: { $0.id == chosen.id }) {
      return NoteEntry(date: date, state: .note(note), random: false)
    }
    let shift = UserDefaults(suiteName: WidgetSnapshot.groupId)?.integer(forKey: ShuffleNoteIntent.shiftKey) ?? 0
    guard let note = DailyPick.pick(snapshot.notes, day: date, shift: shift) else {
      return NoteEntry(date: date, state: .empty, random: false)
    }
    return NoteEntry(date: date, state: .note(note), random: true)
  }
}

struct NoteWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  let entry: NoteEntry

  private var link: URL {
    if case .note(let note) = entry.state { return StowaLink.note(note.id) }
    return StowaLink.home
  }

  var body: some View {
    let palette = StowaPalette.of(scheme)
    switch family {
    case .accessoryInline:
      NoteLockInline(state: entry.state)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(link)
    case .accessoryRectangular:
      NoteLockCard(state: entry.state)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(link)
    default:
      NoteCard(state: entry.state, size: size, random: entry.random, palette: palette)
        .overlay(alignment: .topTrailing) {
          // кружок «другая» рисует NoteCard; кнопка поверх него, шире самого кружка
          if entry.random {
            Button(intent: ShuffleNoteIntent()) {
              Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 9, y: -9)
          }
        }
        .containerBackground(for: .widget) { NoteBackground(state: entry.state, palette: palette) }
        .widgetURL(link)
    }
  }

  private var size: NoteSize {
    switch family {
    case .systemSmall: return .small
    case .systemLarge: return .large
    default: return .medium
    }
  }
}

struct NoteWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "app.stowa.note", intent: PickNoteIntent.self, provider: NoteProvider()) { entry in
      NoteWidgetView(entry: entry)
    }
    .configurationDisplayName(Texts.noteName)
    .description(Texts.noteDescription)
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
  }
}
