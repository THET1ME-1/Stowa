/// Заметки, закреплённые в уведомлениях (идея тестировщицы 16.11.2026: «маркер, который
/// висит сверху телефона, пока сам не снимешь»). Тихое уведомление без звука — в строке
/// состояния, в шторке и на экране блокировки, с кнопкой «Убрать». Время не нужно: это не
/// напоминание, а мысль перед глазами.
library;

import 'reminder_service.dart';

/// Закреплённая заметка: адрес (id или `hidden:id`), заголовок и текст под ним.
typedef Notice = ({String id, String title, String body});

/// prefs: показывать закреплённые на экране блокировки без текста («Код на вход»). Пишет
/// главное окно, читает фоновый проход — у него нет замка хранилища.
const noticePrivatePref = 'notice_private';

/// Кнопка «Убрать» на уведомлении.
const noticeRemove = noticeRemoveAction;

/// Номер уведомления закреплённой заметки: свой, не совпадает с номером её напоминания.
int noticeNotificationId(String itemId) => notificationId('notice:$itemId');

// значки разметки в начале строки и выделение внутри
final _lineMarks = RegExp(r'^(#{1,6}\s+|[-*+]\s+\[[ xX]\]\s+|[-*+]\s+|>\s+|\d+[.)]\s+)');
final _inlineMarks = RegExp(r'\*\*|__|`|~~|==');

/// Текст уведомления: строки под заголовком без разметки, до четырёх и 400 знаков — в шторке
/// уведомление раскрывается и видно мысль целиком, а не одну строку.
String noticeText(String title, String body) {
  final lines = <String>[];
  var first = true;
  for (final raw in body.split('\n')) {
    final line = raw.trim().replaceFirst(_lineMarks, '').replaceAll(_inlineMarks, '').trim();
    if (line.isEmpty || line.startsWith('![[')) continue;
    if (first || line == title.trim()) {
      first = false;
      if (line == title.trim()) continue;
    }
    lines.add(line);
    if (lines.length == 4) break;
  }
  final text = lines.join('\n');
  return text.length > 400 ? '${text.substring(0, 399)}…' : text;
}

/// Держит уведомления закреплённых заметок в согласии с базой: новые показывает, убранные
/// снимает, неизменные не трогает. [force] — показать все заново: смахнутое на Android 14+
/// возвращается при открытии приложения и фоновым проходом.
class NoticeService {
  NoticeService(this._port);

  final NotificationPort _port;
  final _shown = <int, String>{};

  Future<void> sync(List<Notice> notices, {required bool private, bool force = false}) async {
    final wanted = {for (final one in notices) noticeNotificationId(one.id): one};
    for (final id in [..._shown.keys]) {
      if (wanted.containsKey(id)) continue;
      await _port.cancel(id);
      _shown.remove(id);
    }
    for (final MapEntry(key: id, value: one) in wanted.entries) {
      final key = '${one.title}\n${one.body}\n$private';
      if (!force && _shown[id] == key) continue;
      await _port.showPinned(id: id, title: one.title, body: one.body, payload: one.id, private: private);
      _shown[id] = key;
    }
  }

  /// Убрать уведомление заметки сразу, не дожидаясь пересчёта (кнопка «Убрать»).
  Future<void> remove(String itemId) async {
    final id = noticeNotificationId(itemId);
    _shown.remove(id);
    await _port.cancel(id);
  }
}
