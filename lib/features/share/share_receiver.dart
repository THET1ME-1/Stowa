import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart';
import '../../services/share_intake.dart';
import '../composer/panel_text.dart';
import '../composer/picked_files.dart';
import 'share_sheet.dart';

/// Сколько окно ждёт файлы после листа, прежде чем отдать их фону.
const _shareWait = Duration(seconds: 3);

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
      final l = L.of(context);
      final capture = ref.read(captureServiceProvider);
      final failures = <CopyFailure>[];
      final listening = capture.copyFailures.listen((failure) {
        failures.add(failure);
        // файл так и не скопировался, а слов нет: лист про пустую вещь только врал бы
        if (failure.removed && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
      final id = await saveShared(ref, await widget.load(), l: l);
      if (!mounted) return;
      if (id != null) {
        await showShareSheet(context, id);
        // окно закрывается вместе с движком: большой ролик окно не держит, его доделает фон
        await capture.settled().timeout(_shareWait, onTimeout: () => ref.read(fileWorkProvider)());
        // отписку не ждём: ей нечего дожидаться, а ожидание сдвигает плашку на кадр
        unawaited(listening.cancel());
        final failure = failures.where((one) => one.itemId == id).firstOrNull;
        if (failure != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.removed ? l.shareFailed : l.copyPartlyFailed(failure.failed))));
          await Future<void>.delayed(const Duration(milliseconds: 2500));
        }
      } else {
        unawaited(listening.cancel());
        // источник не дал прочитать файл: молча закрыться — значит оставить человека гадать
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.shareFailed)));
        await Future<void>.delayed(const Duration(milliseconds: 2500));
      }
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
/// [l] даёт подпись «Фото от 3 ноября» вместо имени файла с камеры.
Future<String?> saveShared(WidgetRef ref, List<SharedPiece> pieces, {L? l}) async {
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
  final first = files.firstOrNull;
  final untitled = l == null || first == null ? null : (DateTime at) => untitledFor(l, mime: first.mime, fileName: p.basename(first.path), at: at);
  return ref.read(captureServiceProvider).capture(CaptureInput(text: shared.text, files: files, untitled: untitled));
}
