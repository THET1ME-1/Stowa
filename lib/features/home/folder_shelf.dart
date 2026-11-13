import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/db/database.dart' show SmartFolder;
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';

const _gap = 8.0;
const _height = 38.0;

/// Уже пилюля папки не сжимается: значок и пара букв имени.
const _squeezed = 80.0;

/// Сколько цветных кружков спрятанных папок на «+N».
const _moreDots = 3;
const _dot = 14.0;
const _dotStep = 9.0;

/// Папки на главной цветными пилюлями в одну строку во всю ширину: влезающие растягиваются
/// до правого края, остальные прячутся в «+N» с кружками их цветов. «+N» раскрывает все
/// переносом, «Свернуть» возвращает строку. Вбок не листаются: папки видны сразу.
class FolderShelf extends StatefulWidget {
  const FolderShelf({super.key, required this.folders, required this.onOpen, this.onInbox, this.smart = const [], this.onSmart});

  final List<FolderCard> folders;
  final ValueChanged<FolderCard> onOpen;

  /// Умные папки: сохранённые запросы, графитовыми пилюлями со значком поиска после обычных.
  final List<SmartFolder> smart;
  final ValueChanged<SmartFolder>? onSmart;

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
    final smart = widget.smart;
    final total = folders.length + smart.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: LayoutBuilder(
        builder: (context, box) {
          final label = Theme.of(context).textTheme.labelLarge!;
          final scaler = MediaQuery.textScalerOf(context);
          double width(String text) => (TextPainter(text: TextSpan(text: text, style: label), textScaler: scaler, maxLines: 1, textDirection: Directionality.of(context))..layout()).width;
          // метка «новая» мельче имени: её ширина с запасом по шрифту имени
          double pill(FolderCard folder) => FolderPill.widthFor(width(folder.name), width('${folder.count}')) + (folder.createdByAi ? 6 + 14 + width(l.folderNewBadge) : 0);
          final pills = [for (final folder in folders) pill(folder), for (final one in smart) _PlainPill.widthFor(width(one.name).clamp(0, FolderPill._nameMax))];
          final inboxLabel = _PlainPill.widthFor(width(l.folderNone));
          double moreWidth(int hidden) => _MorePill.widthFor(width('+$hidden'), math.min(hidden, _moreDots));
          final row = _open ? null : _oneRow(pills, box.maxWidth, inbox: widget.onInbox == null ? null : inboxLabel, more: moreWidth);

          final Widget body;
          if (row == null) {
            body = Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (final folder in folders) FolderPill(folder: folder, onTap: () => widget.onOpen(folder)),
                for (final one in smart) _PlainPill(icon: 'manage_search', label: one.name, onTap: () => widget.onSmart?.call(one)),
                if (widget.onInbox case final onInbox?) _PlainPill(icon: 'inbox', label: l.folderNone, onTap: onInbox),
                if (total > 0 && _folds(pills, box.maxWidth, widget.onInbox == null ? null : inboxLabel, moreWidth))
                  _PlainPill(icon: 'expand_less', label: l.fullCollapse, onTap: () => setState(() => _open = false)),
              ],
            );
          } else {
            final hidden = [...folders.skip(row.count).map((folder) => folder.color), for (final _ in smart.skip((row.count - folders.length).clamp(0, smart.length))) Tokens.containerHighest];
            final shownSmart = smart.take((row.count - folders.length).clamp(0, smart.length)).toList();
            var index = 0;
            double next() => row.widths[index++];
            body = Row(
              children: [
                for (final (position, folder) in folders.take(row.count).indexed) ...[
                  if (position > 0) const SizedBox(width: _gap),
                  FolderPill(folder: folder, width: next(), onTap: () => widget.onOpen(folder)),
                ],
                for (final one in shownSmart) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  _PlainPill(icon: 'manage_search', label: one.name, width: next(), onTap: () => widget.onSmart?.call(one)),
                ],
                if (widget.onInbox case final onInbox?) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  // места мало — «Без папки» круглым значком, подпись в подсказке
                  if (row.inboxLabeled)
                    _PlainPill(icon: 'inbox', label: l.folderNone, width: next(), onTap: onInbox)
                  else
                    _RoundPill(icon: 'inbox', tooltip: l.folderNone, size: next(), onTap: onInbox),
                ],
                if (hidden.isNotEmpty) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  _MorePill(key: const ValueKey('folders-more'), colors: hidden, width: next(), onTap: () => setState(() => _open = true)),
                ],
              ],
            );
          }
          return AnimatedSize(duration: Motion.medium, curve: Motion.emphasized, alignment: Alignment.topCenter, child: body);
        },
      ),
    );
  }

  /// Одна строка: сколько пилюль (папки, потом умные) влезает с хвостом и какой ширины каждая
  /// после растяжки до правого края. [pills] — их ширины по порядку, [inbox] — «Без папки» с подписью.
  /// Порядок попыток: все с подписанной «Без папки»; все с круглой; меньше, с круглой и «+N».
  static ({int count, bool inboxLabeled, List<double> widths})? _oneRow(
    List<double> pills,
    double max, {
    double? inbox,
    required double Function(int hidden) more,
  }) {
    ({int count, bool inboxLabeled, List<double> widths})? attempt(int count, {required bool labeled, bool squeeze = false}) {
      final hidden = pills.length - count;
      final tail = [if (inbox != null) labeled ? inbox : _height, if (hidden > 0) more(hidden)];
      final natural = [...pills.take(count), ...tail];
      var used = natural.fold(0.0, (sum, width) => sum + width) + _gap * (natural.length - 1);
      // последняя попытка: одна папка сжимается, имя обрезается многоточием
      if (squeeze && count == 1 && used > max && natural.first - (used - max) >= _squeezed) {
        natural[0] -= used - max;
        used = max;
      }
      if (used > max) return null;
      // остаток поровну пилюлям с текстом: круглый значок остаётся кругом
      final round = inbox != null && !labeled;
      final stretchy = natural.length - (round ? 1 : 0);
      final extra = stretchy == 0 ? 0.0 : (max - used) / stretchy;
      final roundIndex = round ? count : -1;
      return (
        count: count,
        inboxLabeled: inbox != null && labeled,
        widths: [for (final (index, width) in natural.indexed) index == roundIndex ? width : width + extra],
      );
    }

    if (attempt(pills.length, labeled: true) case final row?) return row;
    if (inbox != null) {
      if (attempt(pills.length, labeled: false) case final row?) return row;
    }
    // хотя бы одна папка видна всегда, даже на узком экране с крупным шрифтом
    for (var count = pills.length - 1; count >= 1; count--) {
      if (attempt(count, labeled: true) case final row?) return row;
      if (inbox != null) {
        if (attempt(count, labeled: false) case final row?) return row;
      }
    }
    if (pills.isEmpty) return null;
    return attempt(1, labeled: false, squeeze: true);
  }

  /// Не влезает ли всё в одну строку: тогда у раскрытого списка есть «Свернуть».
  static bool _folds(List<double> pills, double max, double? inbox, double Function(int hidden) more) {
    final row = _oneRow(pills, max, inbox: inbox, more: more);
    return row == null || row.count < pills.length;
  }
}

/// Папка пилюлей в своём цвете: значок, имя и число заметок тёмным по цвету.
class FolderPill extends StatelessWidget {
  const FolderPill({super.key, required this.folder, required this.onTap, this.width});

  final FolderCard folder;
  final VoidCallback onTap;

  /// Ширина в строке полки: растянута до правого края, содержимое по центру. Без неё — по тексту.
  final double? width;

  /// Ширина пилюли по ширине имени и числа: по ней полка решает, что влезает в две строки.
  // отступ 12, значок 18, щель 6, имя, щель 7, число, отступ 14 и 2 точки запаса на округление:
  // лишние 14 сверху прятали в «Ещё» папку, которая на экране влезала
  static double widthFor(double name, double count) => 12 + 18 + 6 + name.clamp(0, _nameMax) + 7 + count + 14 + 2;

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
        width: width,
        padding: const EdgeInsets.only(left: 12, right: 14),
        decoration: BoxDecoration(color: folder.color, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // у открытой скрытой папки вместо её значка замок: видно, что она закроется сама
            Icon(symbolIcon(folder.hidden ? 'lock' : folder.icon, filled: true), size: 18, color: ink),
            const SizedBox(width: 6),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _nameMax),
                child: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: label.copyWith(color: ink)),
              ),
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

/// Графитовая пилюля без цвета: «Без папки», умная папка, «Свернуть».
class _PlainPill extends StatelessWidget {
  const _PlainPill({required this.icon, required this.label, required this.onTap, this.width});

  final String icon;
  final String label;
  final VoidCallback onTap;
  final double? width;

  static double widthFor(double label) => 12 + 18 + 6 + label + 16 + 2;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: _height,
        width: width,
        padding: const EdgeInsets.only(left: 12, right: 16),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(symbolIcon(icon), size: 18, color: Tokens.onSurfaceVariant),
            const SizedBox(width: 6),
            // имя умной папки бывает длинным запросом: обрезается, как имя обычной
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: FolderPill._nameMax),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurface)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Без папки» кругом, когда подписи нет места: значок тот же, подпись — в подсказке.
class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.icon, required this.tooltip, required this.size, required this.onTap});

  final String icon;
  final String tooltip;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.94,
        child: Container(
          width: size,
          height: _height,
          decoration: BoxDecoration(color: Tokens.containerHigh, shape: BoxShape.circle),
          child: Icon(symbolIcon(icon), size: 18, color: Tokens.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// «+N»: стопка кружков цветов спрятанных папок и их число — видно, что за ней и сколько.
class _MorePill extends StatelessWidget {
  const _MorePill({super.key, required this.colors, required this.width, required this.onTap});

  final List<Color> colors;
  final double width;
  final VoidCallback onTap;

  /// Отступ 10, кружки внахлёст, щель 6, число, отступ 14 и 2 точки запаса.
  static double widthFor(double label, int dots) => 10 + _dot + _dotStep * (dots - 1) + 6 + label + 14 + 2;

  @override
  Widget build(BuildContext context) {
    final dots = colors.take(_moreDots).toList();
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: _height,
        width: width,
        padding: const EdgeInsets.only(left: 10, right: 14),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: _dot + _dotStep * (dots.length - 1),
              height: _dot,
              child: Stack(
                children: [
                  // кружок обведён цветом подложки: внахлёст они не сливаются
                  for (final (index, color) in dots.indexed)
                    Positioned(
                      left: _dotStep * index,
                      child: Container(
                        width: _dot,
                        height: _dot,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Tokens.containerHigh, width: 2)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('+${colors.length}', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.onSurface)),
          ],
        ),
      ),
    );
  }
}
