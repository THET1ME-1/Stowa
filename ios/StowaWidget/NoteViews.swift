import SwiftUI

/// Размер виджета заметки на главном экране.
enum NoteSize {
  case small, medium, large

  /// Сколько строк заметки помещается под заголовком.
  var lines: Int {
    switch self {
    case .small: return 3
    case .medium: return 4
    case .large: return 8
    }
  }
}

/// Заметка на главном экране: заголовок, под ним строки, пункты списка — с кружками.
/// В случайном выборе в углу кружок «другая»: кнопку на нём ставит NoteWidget.swift.
struct NoteCard: View {
  let state: NoteState
  let size: NoteSize
  let random: Bool
  let palette: StowaPalette

  var body: some View {
    switch state {
    case .note(let note): filled(note)
    case .locked: notice(icon: "lock.fill", text: Texts.locked)
    case .empty: notice(icon: "note.text", text: Texts.empty)
    }
  }

  private func filled(_ note: WidgetNote) -> some View {
    let shown = Array(note.lines.prefix(size.lines))
    let rest = note.lines.count - shown.count
    return VStack(alignment: .leading, spacing: size == .large ? 7 : 5) {
      HStack(alignment: .top, spacing: 6) {
        Text(note.title.isEmpty ? Texts.untitled : note.title)
          .font(.system(size: size == .small ? 15 : 16, weight: .semibold))
          .foregroundStyle(Color(argb: palette.onSurface))
          .lineLimit(size == .small && note.lines.isEmpty ? 5 : 2)
          .frame(maxWidth: .infinity, alignment: .leading)
        if random {
          Image(systemName: "shuffle")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(argb: palette.muted))
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color(argb: palette.containerHigh)))
        }
      }
      ForEach(Array(shown.enumerated()), id: \.offset) { _, line in
        NoteLineRow(line: line, compact: size != .large, palette: palette)
      }
      Spacer(minLength: 0)
      if rest > 0 {
        Text(Texts.more(rest))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color(argb: palette.muted))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func notice(icon: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(Color(argb: palette.onSurface))
      Spacer(minLength: 0)
      Text(text)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color(argb: palette.onSurfaceVariant))
        .lineLimit(4)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

/// Строка заметки: у пункта списка кружок, отмеченный — зачёркнут и приглушён.
struct NoteLineRow: View {
  let line: WidgetNote.Line
  let compact: Bool
  let palette: StowaPalette

  var body: some View {
    let done = line.done == true
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if let checked = line.done {
        Image(systemName: checked ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color(argb: checked ? palette.muted : palette.onSurfaceVariant))
      }
      Text(line.text)
        .font(.system(size: 13))
        .strikethrough(done)
        .foregroundStyle(Color(argb: done ? palette.muted : palette.onSurfaceVariant))
        .lineLimit(compact ? 1 : 2)
    }
  }
}

/// Подложка виджета заметки: цвет её папки, без папки — контейнер темы.
struct NoteBackground: View {
  let state: NoteState
  let palette: StowaPalette

  var body: some View {
    if case .note(let note) = state {
      palette.tint(note.color)
    } else {
      Color(argb: palette.container)
    }
  }
}

/// Экран блокировки, прямоугольник: заголовок и две первые строки. Цвет даёт система.
struct NoteLockCard: View {
  let state: NoteState

  var body: some View {
    switch state {
    case .note(let note):
      VStack(alignment: .leading, spacing: 1) {
        Text(note.title.isEmpty ? Texts.untitled : note.title)
          .font(.system(size: 15, weight: .semibold))
          .lineLimit(1)
        ForEach(Array(note.lines.prefix(2).enumerated()), id: \.offset) { _, line in
          HStack(spacing: 4) {
            if let done = line.done { Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 11)) }
            Text(line.text).font(.system(size: 13)).lineLimit(1)
          }
          .opacity(line.done == true ? 0.6 : 1)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .locked:
      Label(Texts.locked, systemImage: "lock.fill").font(.system(size: 14, weight: .semibold))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    case .empty:
      Text(Texts.empty).font(.system(size: 13, weight: .medium)).lineLimit(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

/// Экран блокировки, строка над часами: только заголовок.
struct NoteLockInline: View {
  let state: NoteState

  var body: some View {
    switch state {
    case .note(let note): Label(note.title.isEmpty ? Texts.untitled : note.title, systemImage: "note.text")
    case .locked: Label(Texts.locked, systemImage: "lock.fill")
    case .empty: Label("Stowa", systemImage: "note.text")
    }
  }
}
