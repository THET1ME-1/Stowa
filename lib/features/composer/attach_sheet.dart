import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

enum AttachSource { gallery, photo, video, files }

/// Лист «Прикрепить» снизу. Выбор файлов открывается после того, как лист
/// закрылся, иначе системное окно ляжет поверх листа.
Future<AttachSource?> showAttachSheet(BuildContext context) {
  return showModalBottomSheet<AttachSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final l = L.of(context);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.screen),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Row(icon: 'photo_library', title: l.attachGallery, hint: l.attachGalleryHint, source: AttachSource.gallery),
            _Row(icon: 'photo_camera', title: l.attachCamera, source: AttachSource.photo),
            _Row(icon: 'videocam', title: l.attachVideo, source: AttachSource.video),
            _Row(icon: 'folder_open', title: l.attachFile, hint: l.attachFileHint, source: AttachSource.files),
          ]),
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.source, this.hint});

  final String icon;
  final String title;
  final String? hint;
  final AttachSource source;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.tile),
      onTap: () => Navigator.pop(context, source),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: Tokens.containerHighest, shape: BoxShape.circle),
            child: Icon(symbolIcon(icon, filled: true), color: Tokens.onSurface),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleMedium),
              if (hint != null) Text(hint!, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
