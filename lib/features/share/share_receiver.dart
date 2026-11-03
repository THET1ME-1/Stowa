import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../data/providers.dart';
import '../../services/capture_service.dart';
import '../../services/share_intake.dart';
import '../composer/picked_files.dart';
import 'share_sheet.dart';

/// Окно «Поделиться»: прозрачное, поверх приложения, из которого делятся.
/// Сохраняет присланное, показывает лист и закрывается, телефон возвращается обратно.
class ShareHost extends ConsumerStatefulWidget {
  const ShareHost({super.key, this.load = loadSharedPieces, this.onFinish = SystemNavigator.pop});

  /// Что прислали. В тестах подменяется.
  final Future<List<SharedPiece>> Function() load;

  /// Закрыть окно.
  final Future<void> Function() onFinish;

  @override
  ConsumerState<ShareHost> createState() => _ShareHostState();
}

class _ShareHostState extends ConsumerState<ShareHost> {
  @override
  void initState() {
    super.initState();
    // напоминание из присланного текста встаёт сразу, не дожидаясь главного окна
    ref.listenManual(remindersProvider, (previous, next) {
      final reminders = next.value;
      if (reminders != null) ref.read(reminderServiceProvider).sync(reminders, ref.read(clockProvider)());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final id = await saveShared(ref, await widget.load());
      if (id != null && mounted) await showShareSheet(context, id);
    } finally {
      await widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: Colors.transparent);
}

/// Присланное системой. Нет плагина (тесты) — пусто.
Future<List<SharedPiece>> loadSharedPieces() async {
  try {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    unawaited(ReceiveSharingIntent.instance.reset());
    return [
      for (final one in media)
        SharedPiece(
          value: one.path,
          mime: one.mimeType,
          kind: switch (one.type) {
            SharedMediaType.text => SharedKind.text,
            SharedMediaType.url => SharedKind.url,
            SharedMediaType.image => SharedKind.image,
            SharedMediaType.video => SharedKind.video,
            SharedMediaType.file => SharedKind.file,
          },
        ),
    ];
  } on MissingPluginException {
    return const [];
  }
}

/// Сохранить присланное одной вещью. Вернёт её id или null, если сохранять нечего.
Future<String?> saveShared(WidgetRef ref, List<SharedPiece> pieces) async {
  final shared = sharedToCapture(pieces);
  if (shared.isEmpty) return null;
  final files = <PickedFile>[];
  for (final file in shared.files) {
    try {
      files.add(await pickedFrom(file.path, hint: file.mime));
    } catch (_) {
      // файл не прочитался: остальное всё равно сохраняем
    }
  }
  if (shared.text.isEmpty && files.isEmpty) return null;
  return ref.read(captureServiceProvider).capture(CaptureInput(text: shared.text, files: files));
}
