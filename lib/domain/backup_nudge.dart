/// Что сказать человеку, у которого заметки лежат только в браузере.
enum BackupNudge {
  /// Ничего: копия свежая, заметок нет или напоминание отложено.
  none,

  /// Копии ни разу не было: заметки живут в одном месте, и браузер вправе их стереть.
  first,

  /// Копия устарела: с неё прошла неделя с правками или набралось много правок.
  stale,
}

/// Через сколько дней копия считается старой.
const backupStaleAfter = Duration(days: 7);

/// Сколько правок после копии — уже повод сохранить новую, не дожидаясь недели.
const backupStaleEdits = 50;

/// Пора ли напомнить о резервной копии.
///
/// Заметки «в этом браузере» лежат в личной папке сайта: браузер стирает её, когда кончается
/// место, а Safari — через неделю без захода. Терять их молча нельзя, поэтому приложение
/// предупреждает один раз и напоминает, когда копия устарела.
///
/// [notes] — сколько заметок в хранилище, [editedSince] — сколько из них правили после
/// [lastCopy] (без копии — сколько всего), [snoozedUntil] — до какого времени человек
/// попросил не напоминать.
BackupNudge backupNudge({required DateTime now, required int notes, required int editedSince, DateTime? lastCopy, DateTime? snoozedUntil}) {
  if (notes == 0) return BackupNudge.none;
  if (snoozedUntil != null && now.isBefore(snoozedUntil)) return BackupNudge.none;
  if (lastCopy == null) return BackupNudge.first;
  // копию с тех пор не меняли: напоминать нечего, сколько бы времени ни прошло
  if (editedSince == 0) return BackupNudge.none;
  if (editedSince >= backupStaleEdits || now.difference(lastCopy) >= backupStaleAfter) return BackupNudge.stale;
  return BackupNudge.none;
}
