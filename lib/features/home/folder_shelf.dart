import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';

/// Сколько строк пилюль видно сразу; остальные папки — по «Ещё».
const _rows = 2;

const _gap = 8.0;
const _height = 38.0;

/// Папки на главной цветными пилюлями. Переносятся на новую строку, вбок не листаются.
class FolderShelf extends StatefulWidget {
  const FolderShelf({super.key, required this.folders, required this.onOpen, this.onInbox});

  final List<FolderCard> folders;
  final ValueChanged<FolderCard> onOpen;

  /// Есть неразложенное: в конце серая пилюля «Без папки».
  final VoidCallback? onInbox;

  @override
  State<FolderShelf> createState() => _FolderShelfState();
}

class _FolderShelfState extends State<FolderShelf> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final folders = widget.folders;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: LayoutBuilder(
        builder: (context, box) {
          final label = Theme.of(context).textTheme.labelLarge!;
          final scaler = MediaQuery.textScalerOf(context);
          double width(String text) => (TextPainter(text: TextSpan(text: text, style: label), textScaler: scaler, maxLines: 1, textDirection: Directionality.of(context))..layout()).width;
          final inbox = widget.onInbox == null ? 0.0 : _PlainPill.widthFor(width(l.folderNone));
          // сколько папок влезает в две строки, если в конце ещё «Без папки» и «Ещё N»
          // метка «новая» мельче имени: её ширина с запасом по шрифту имени
          double pill(FolderCard folder) => FolderPill.widthFor(width(folder.name), width('${folder.count}')) + (folder.createdByAi ? 6 + 14 + width(l.folderNewBadge) : 0);
          final fit = _open ? folders.length : _fitting(folders, box.maxWidth, inbox, pill, (hidden) => _PlainPill.widthFor(width(l.homeFoldersMore(hidden))));
          final folded = fit < folders.length;
          return AnimatedSize(
            duration: Motion.medium,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final folder in folders.take(fit)) FolderPill(folder: folder, onTap: () => widget.onOpen(folder)),
                if (widget.onInbox case final onInbox?) _PlainPill(icon: 'inbox', label: l.folderNone, onTap: onInbox),
                if (folded)
                  _PlainPill(icon: 'expand_more', label: l.homeFoldersMore(folders.length - fit), onTap: () => setState(() => _open = true))
                else if (_open)
                  _PlainPill(icon: 'expand_less', label: l.fullCollapse, onTap: () => setState(() => _open = false)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Число папок, которые вместе с хвостом («Без папки», «Ещё N») ложатся в [_rows] строк.
  static int _fitting(List<FolderCard> folders, double max, double inbox, double Function(FolderCard) pill, double Function(int hidden) more) {
    bool fits(int count) {
      final widths = [
        for (final folder in folders.take(count)) pill(folder),
        if (inbox > 0) inbox,
        if (count < folders.length) more(folders.length - count),
      ];
      var rows = 1;
      var line = 0.0;
      for (final width in widths) {
        final next = line == 0 ? width : line + _gap + width;
        if (next > max && line > 0) {
          rows++;
          line = width;
        } else {
          line = next;
        }
      }
      return rows <= _rows;
    }

    if (fits(folders.length)) return folders.length;
    var count = folders.length - 1;
    // хотя бы одна папка видна всегда, даже на узком экране с крупным шрифтом
    while (count > 1 && !fits(count)) {
      count--;
    }
    return count;
  }
}

/// Папка пилюлей в своём цвете: значок, имя и число заметок тёмным по цвету.
class FolderPill extends StatelessWidget {
  const FolderPill({super.key, required this.folder, required this.onTap});

  final FolderCard folder;
  final VoidCallback onTap;

  /// Ширина пилюли по ширине имени и числа: по ней полка решает, что влезает в две строки.
  static double widthFor(double name, double count) => 12 + 18 + 6 + name.clamp(0, _nameMax) + 7 + count + 14 + 14;

  static const _nameMax = 180.0;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelLarge!;
    final ink = inkOn(folder.color);
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: _height,
        padding: const EdgeInsets.only(left: 12, right: 14),
        decoration: BoxDecoration(color: folder.color, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon(folder.icon, filled: true), size: 18, color: ink),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _nameMax),
              child: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: label.copyWith(color: ink)),
            ),
            const SizedBox(width: 7),
            // число бледнее имени: видно, но не спорит с ним
            Text('${folder.count}', style: label.copyWith(color: ink.withValues(alpha: 0.55))),
            // ИИ завёл папку, а человек в неё ещё не заглядывал
            if (folder.createdByAi) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(100)),
                child: Text(L.of(context).folderNewBadge, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: folder.color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Графитовая пилюля без цвета: «Без папки», «Ещё», «Свернуть».
class _PlainPill extends StatelessWidget {
  const _PlainPill({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  static double widthFor(double label) => 12 + 18 + 6 + label + 16 + 2;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: _height,
        padding: const EdgeInsets.only(left: 12, right: 16),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon(icon), size: 18, color: Tokens.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurface)),
          ],
        ),
      ),
    );
  }
}
