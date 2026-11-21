/// Ход полного прохода синхронизации, как его видит человек на экране «Stowa Sync».
/// Без Flutter: о ходе сообщают и движок, и сверка хранилища.
library;

/// Этап прохода. Сверка папки и раскладка заметок — работа сверки хранилища,
/// приём и отправка — движка синхронизации.
enum SyncStage {
  /// Правки, сделанные в папке снаружи, и свои — в файлы.
  folder,

  /// Чужие правки с сервера.
  receive,

  /// Свои правки на сервер: файлы сверяются с сервером, отличные уходят.
  send,

  /// Пришедшие файлы ложатся в заметки.
  place,
}

class SyncProgress {
  const SyncProgress(this.stage, {this.done = 0, this.total, this.bytesDone = 0, this.bytesTotal = 0, this.file});

  final SyncStage stage;

  /// Файлов этапа сделано.
  final int done;

  /// Файлов этапа всего; null — ещё не известно.
  final int? total;

  final int bytesDone;

  /// Байт этапа всего; 0 — этап меряется файлами.
  final int bytesTotal;

  /// Путь файла, который идёт сейчас.
  final String? file;

  /// Доля этапа от 0 до 1; null — сколько всего, пока не известно. Сеть возит байты,
  /// поэтому, когда они известны, доля — по ним: большое фото не стоит одним шагом.
  double? get fraction {
    final all = total;
    if (all == null) return null;
    if (all == 0) return 1;
    if (bytesTotal > 0) return (bytesDone / bytesTotal).clamp(0.0, 1.0);
    return (done / all).clamp(0.0, 1.0);
  }
}
