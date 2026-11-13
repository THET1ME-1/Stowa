import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart';
import '../composer/smart_punctuation.dart';
import '../folder/folder_sheets.dart';

const _countdown = Duration(seconds: 3);

/// Лист после «Поделиться», как экран 9 макета: всё уже сохранено, папку можно
/// сменить, дописать пару слов. Сам закрывается через три секунды, если не трогать.
Future<void> showShareSheet(BuildContext context, String itemId) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    // ручка своя, как в макете
    showDragHandle: false,
    backgroundColor: Tokens.containerLow,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(top: false, child: ShareSheet(itemId: itemId)),
    ),
  );
}

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(vsync: this, duration: _countdown)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _close();
    });
  final _words = TextEditingController();
  bool _closing = false;
  bool _touched = false;
  Animation<double>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // три секунды идут с той минуты, когда лист виден целиком: на холодном
    // запуске первые кадры рисуются долго, и отсчёт съедал бы весь показ
    final route = ModalRoute.of(context)?.animation;
    if (route == null || route == _route) return;
    _route?.removeStatusListener(_onRoute);
    _route = route..addStatusListener(_onRoute);
    _onRoute(route.status);
  }

  void _onRoute(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_touched && !_timer.isAnimating && _timer.value == 0) _timer.forward();
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onRoute);
    _timer.dispose();
    _words.dispose();
    super.dispose();
  }

  // тронул лист — отсчёт останавливается, дальше человек решает сам
  void _hold() {
    if (_touched) return;
    setState(() {
      _touched = true;
      _timer.stop();
    });
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    final words = _words.text.trim();
    if (words.isNotEmpty) await ref.read(itemsRepositoryProvider).append(widget.itemId, words, ref.read(clockProvider)());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _move(String folderId) async {
    _hold();
    await ref.read(itemsRepositoryProvider).moveToFolder(widget.itemId, folderId, ref.read(clockProvider)());
  }

  Future<void> _newFolder() async {
    _hold();
    final name = await showRenameSheet(context, '');
    if (name == null) return;
    final folder = await ref.read(foldersRepositoryProvider).create(name);
    await _move(folder.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final item = ref.watch(itemProvider(widget.itemId)).value;
    final folders = ref.watch(foldersProvider).value ?? const [];
    final folderId = item?.item.folderId;
    final folder = folders.where((one) => one.id == folderId).firstOrNull;
    final image = item?.attachments.where((file) => file.mime.startsWith('image/')).firstOrNull;
    final filesRoot = ref.watch(filesRootProvider);
    // своя папка первой, потом остальные
    final choices = [?folder, ...folders.where((one) => one.id != folderId)].take(6).toList();

    return Listener(
      onPointerDown: (_) => _hold(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 10, Space.screen, Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 32, height: 4, decoration: BoxDecoration(color: Tokens.outline, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox.square(
                    dimension: 64,
                    child: image != null
                        ? Image.file(File(p.join(filesRoot.path, image.path)), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHigh))
                        : ColoredBox(
                            color: Tokens.containerHigh,
                            child: Icon(symbolIcon(item == null ? 'check' : kindIcon(item.item.kind), filled: true), size: 28, color: Tokens.onSurface),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.shareSaved, style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.4)),
                      const SizedBox(height: 2),
                      Text(
                        folder == null ? l.shareNoFolder : l.shareInFolder(folder.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(fontSize: 14, color: Tokens.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Ring(timer: _timer, held: _touched),
              ],
            ),
            const SizedBox(height: 20),
            Text(l.shareOther, style: text.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in choices)
                  _Chip(icon: choice.icon, label: choice.name, on: choice.id == folderId, onTap: () => _move(choice.id)),
                _Chip(icon: 'add', label: l.shareNewFolder, on: false, onTap: _newFolder),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _words,
              onTap: _hold,
              inputFormatters: [TextInputFormatter.withFunction(smartPunctuation)],
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                prefixIcon: Icon(symbolIcon('edit'), size: 20),
                hintText: l.shareAddWords,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                fillColor: Tokens.containerHigh,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _close, child: Text(l.shareDone)),
          ],
        ),
      ),
    );
  }
}

/// Кольцо обратного отсчёта с цифрой, как в макете.
class _Ring extends StatelessWidget {
  const _Ring({required this.timer, required this.held});

  final AnimationController timer;

  /// Человек тронул лист: цифры больше нет, кольцо замерло.
  final bool held;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timer,
      builder: (context, _) {
        final left = (_countdown.inSeconds * (1 - timer.value)).ceil();
        return SizedBox.square(
          dimension: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: 38,
                child: CircularProgressIndicator(value: 1 - timer.value, strokeWidth: 3, color: Tokens.accent, backgroundColor: Tokens.outline, strokeCap: StrokeCap.round),
              ),
              if (!held)
                Text('$left', style: Theme.of(context).textTheme.labelLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.on, required this.onTap});

  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? Tokens.onAccent : Tokens.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: on ? Tokens.accent : Tokens.containerHigh, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbolIcon(icon), size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
