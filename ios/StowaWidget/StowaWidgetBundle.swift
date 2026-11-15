import SwiftUI
import WidgetKit

/// Виджеты Stowa: строка и заметка.
///
/// Ни одного `if #available` здесь: ветка компилируется в
/// `WidgetBundleBuilder.buildLimitedAvailability`, и расширение падает, когда система просит
/// у него список виджетов, — пропадают все (урок Togetherly, 1.28.4). Поэтому минимальная
/// iOS расширения — 17: тогда и экран блокировки, и настройка на AppIntents объявляются
/// безусловно. Приложение по-прежнему живёт с iOS 15, просто на 15–16 виджетов нет.
@main
struct StowaWidgetBundle: WidgetBundle {
  var body: some Widget {
    ComposerWidget()
    NoteWidget()
  }
}
