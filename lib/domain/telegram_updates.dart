/// Файл в сообщении бота: скачивается потом через getFile.
class TelegramFileRef {
  const TelegramFileRef({required this.fileId, required this.fileName, required this.mime});

  final String fileId;
  final String fileName;
  final String mime;
}

/// Сообщение, которое станет вещью. Альбом склеен в одно.
class IncomingMessage {
  const IncomingMessage({required this.updateId, required this.fromId, required this.text, required this.files, required this.date});

  /// Последний update_id сообщения: offset двигается за него только после записи вещи.
  final int updateId;
  final int fromId;
  final String text;
  final List<TelegramFileRef> files;
  final DateTime date;
}

/// Кто писал боту, в том числе командой: первый — хозяин.
class TelegramSender {
  const TelegramSender({required this.id, required this.name});

  final int id;
  final String name;
}

class TelegramUpdates {
  const TelegramUpdates({required this.messages, required this.lastUpdateId, required this.senders});

  final List<IncomingMessage> messages;

  /// Самый поздний update_id, включая пропущенные: стикеры и правки тоже надо отметить прочитанными.
  final int? lastUpdateId;
  final List<TelegramSender> senders;
}

/// Ответ getUpdates → вещи. Стикеры, команды, правки и служебные сообщения
/// пропускаются; альбом (общий media_group_id) — одна вещь со всеми файлами.
TelegramUpdates parseUpdates(Map<String, Object?> json) {
  final updates = json['result'] is List ? json['result'] as List : const [];
  int? last;
  final senders = <TelegramSender>[];
  final messages = <IncomingMessage>[];
  final albums = <String, int>{};

  for (final raw in updates) {
    if (raw is! Map<String, Object?>) continue;
    final updateId = raw['update_id'];
    if (updateId is! int) continue;
    if (last == null || updateId > last) last = updateId;
    final message = raw['message'];
    if (message is! Map<String, Object?>) continue;

    final from = message['from'];
    if (from is! Map<String, Object?> || from['id'] is! int) continue;
    final fromId = from['id']! as int;
    if (!senders.any((sender) => sender.id == fromId)) senders.add(TelegramSender(id: fromId, name: from['first_name'] as String? ?? ''));

    final text = _text(message);
    if (text.startsWith('/')) continue;
    final files = _files(message);
    if (text.isEmpty && files.isEmpty) continue;
    final date = DateTime.fromMillisecondsSinceEpoch(((message['date'] as int?) ?? 0) * 1000);

    final group = message['media_group_id'];
    final index = group is String ? albums[group] : null;
    if (index != null) {
      final first = messages[index];
      messages[index] = IncomingMessage(
        updateId: updateId,
        fromId: fromId,
        text: first.text.isEmpty ? text : first.text,
        files: [...first.files, ...files],
        date: first.date,
      );
      continue;
    }
    if (group is String) albums[group] = messages.length;
    messages.add(IncomingMessage(updateId: updateId, fromId: fromId, text: text, files: files, date: date));
  }
  return TelegramUpdates(messages: messages, lastUpdateId: last, senders: senders);
}

/// Текст или подпись. Ссылки, спрятанные под словами, дописываются строкой:
/// иначе адрес пропал бы, а превью и правила по сайту его не увидели.
String _text(Map<String, Object?> message) {
  final text = (message['text'] ?? message['caption']) as String? ?? '';
  final entities = message['entities'] ?? message['caption_entities'];
  final hidden = <String>[
    for (final entity in entities is List ? entities : const [])
      if (entity is Map<String, Object?> && entity['type'] == 'text_link' && entity['url'] is String && !text.contains(entity['url']! as String)) entity['url']! as String,
  ];
  return [text.trim(), ...hidden].where((part) => part.isNotEmpty).join('\n');
}

List<TelegramFileRef> _files(Map<String, Object?> message) {
  final id = message['message_id'] ?? 0;
  TelegramFileRef? named(Object? raw, String fallbackName, String fallbackMime) {
    if (raw is! Map<String, Object?> || raw['file_id'] is! String) return null;
    return TelegramFileRef(fileId: raw['file_id']! as String, fileName: raw['file_name'] as String? ?? fallbackName, mime: raw['mime_type'] as String? ?? fallbackMime);
  }

  final photo = message['photo'];
  // Telegram присылает фото в нескольких размерах, последнее — самое крупное
  final biggest = photo is List && photo.isNotEmpty ? photo.last : null;
  return [
    ?named(biggest, 'photo_$id.jpg', 'image/jpeg'),
    ?named(message['document'], 'file_$id', 'application/octet-stream'),
    ?named(message['video'], 'video_$id.mp4', 'video/mp4'),
    ?named(message['video_note'], 'video_$id.mp4', 'video/mp4'),
    ?named(message['voice'], 'voice_$id.ogg', 'audio/ogg'),
    ?named(message['audio'], 'audio_$id.mp3', 'audio/mpeg'),
  ];
}
