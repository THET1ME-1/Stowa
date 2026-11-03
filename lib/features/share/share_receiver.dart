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

/// Приём из меню «Поделиться»: вещь сохраняется сразу, потом всплывает лист.
/// Открыли Stowa ради «Поделиться» — после листа телефон возвращается туда, откуда делились.
class ShareReceiver {
  ShareReceiver(this._ref, this._context);

  final WidgetRef _ref;
  final BuildContext Function() _context;
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  void start() {
    try {
      ReceiveSharingIntent.instance.getInitialMedia().then((media) {
        if (media.isNotEmpty) receive(_pieces(media), cold: true);
        ReceiveSharingIntent.instance.reset();
      }).catchError((Object _) {});
      _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        (media) {
          if (media.isNotEmpty) receive(_pieces(media), cold: false);
        },
        onError: (Object _) {},
      );
    } on MissingPluginException {
      // нет плагина (тесты): «Поделиться» просто не слушаем
    }
  }

  void stop() => _subscription?.cancel();

  static List<SharedPiece> _pieces(List<SharedMediaFile> media) => [
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

  /// Сохранить присланное и показать лист.
  Future<void> receive(List<SharedPiece> pieces, {required bool cold}) async {
    final shared = sharedToCapture(pieces);
    if (shared.isEmpty) return;
    final files = <PickedFile>[];
    for (final file in shared.files) {
      try {
        files.add(await pickedFrom(file.path, hint: file.mime));
      } catch (_) {
        // файл не прочитался: остальное всё равно сохраняем
      }
    }
    if (shared.text.isEmpty && files.isEmpty) return;
    final id = await _ref.read(captureServiceProvider).capture(CaptureInput(text: shared.text, files: files));
    final context = _context();
    if (!context.mounted) return;
    await showShareSheet(context, id);
    if (cold) await SystemNavigator.pop();
  }
}
