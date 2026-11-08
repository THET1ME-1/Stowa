import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/note_blocks.dart';
import '../../domain/text_diff.dart';
import '../../l10n/app_localizations.dart';
import '../composer/panel_text.dart';
import 'note_body.dart';

/// История въезжает справа, как страница заметки. Вернули версию — экран отдаёт true.
Route<bool> historyRoute(String itemId) => PageRouteBuilder(
  transitionDuration: Motion.long,
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => HistoryScreen(itemId: itemId),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// «Сегодня, 14:05», «7 нояб., 10:20».
String versionTime(L l, DateTime at, DateTime now) {
  final day = shortDate(l, at, now);
  return '${day[0].toUpperCase()}${day.substring(1)}, ${DateFormat.Hm(l.localeName).format(at)}';
}

/// Версии заметки по времени, новая сверху. Под каждой — сколько строк с тех пор
/// добавили и убрали; касание открывает версию целиком.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final item = ref.watch(itemProvider(itemId)).value?.item;
    final versions = ref.watch(noteVersionsProvider(itemId)).value ?? const <NoteVersion>[];
    final now = ref.read(clockProvider)();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 24 + bottom),
          children: [
            Align(alignment: Alignment.centerLeft, child: _BackButton(onTap: () => Navigator.pop(context))),
            const SizedBox(height: 16),
            Text(l.historyTitle, style: text.headlineMedium!.copyWith(fontSize: 26, height: 1.1, letterSpacing: -0.6)),
            if (item != null) ...[
              const SizedBox(height: 4),
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
            ],
            const SizedBox(height: 20),
            if (item != null)
              _VersionRow(
                time: l.historyNow,
                preview: _preview(item.body, item.title),
                note: versionTime(l, item.updatedAt, now),
                current: true,
                radius: BorderRadius.vertical(top: const Radius.circular(Radii.card), bottom: Radius.circular(versions.isEmpty ? Radii.card : 8)),
              ),
            for (final (index, version) in versions.indexed) ...[
              const SizedBox(height: 4),
              _VersionRow(
                time: versionTime(l, version.savedAt, now),
                preview: _preview(version.body, version.title),
                note: item == null ? null : _changes(l, version, item),
                radius: BorderRadius.vertical(top: const Radius.circular(8), bottom: Radius.circular(index == versions.length - 1 ? Radii.card : 8)),
                onTap: () async {
                  final restored = await Navigator.of(context).push<bool>(_versionRoute(version));
                  if (restored == true && context.mounted) Navigator.pop(context, true);
                },
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(l.historyHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  // первая строка с текстом, без значков разметки
  static String _preview(String body, String title) {
    for (final block in parseNoteBlocks(body)) {
      final line = switch (block) {
        ParagraphBlock(:final text) || HeadingBlock(:final text) || BulletBlock(:final text) || NumberedBlock(:final text) || CheckBlock(:final text) || QuoteBlock(:final text) => text,
      };
      final plain = parseInline(line).map((piece) => piece.text).join().trim();
      if (plain.isNotEmpty && plain != title) return plain;
    }
    return title;
  }

  static String _changes(L l, NoteVersion version, Item item) {
    final counts = diffCounts(diffLines(version.body, item.body));
    if (counts.added == 0 && counts.removed == 0) return l.historyNoChanges;
    return '+${counts.added} −${counts.removed}';
  }

  Route<bool> _versionRoute(NoteVersion version) => PageRouteBuilder(
    transitionDuration: Motion.long,
    reverseTransitionDuration: Motion.medium,
    pageBuilder: (context, animation, secondary) => VersionScreen(version: version),
    transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
      position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
      child: child,
    ),
  );
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(48)),
      icon: Icon(symbolIcon('arrow_back'), size: 22, color: Tokens.onSurface),
    );
  }
}

/// Строка версии: время, первая строка текста и сводка правок. Блоки списка
/// сцеплены, как в настройках: края скруглены только у первого и последнего.
class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.time, required this.preview, required this.radius, this.note, this.current = false, this.onTap});

  final String time;
  final String preview;
  final String? note;
  final bool current;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(color: current ? Tokens.containerHigh : Tokens.container, borderRadius: radius),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: current ? Tokens.accent : Tokens.graphite, shape: BoxShape.circle),
            child: Icon(symbolIcon(current ? 'edit_note' : 'history'), size: 20, color: current ? Tokens.onAccent : Tokens.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                if (note case final note?) ...[
                  const SizedBox(height: 2),
                  Text(note, style: text.bodySmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ],
            ),
          ),
          if (onTap != null) Icon(symbolIcon('chevron_right'), size: 20, color: Tokens.muted),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// Версия целиком: её текст или разница с нынешним, внизу «Вернуть эту версию».
class VersionScreen extends ConsumerStatefulWidget {
  const VersionScreen({super.key, required this.version});

  final NoteVersion version;

  @override
  ConsumerState<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends ConsumerState<VersionScreen> {
  var _diff = false;

  Future<void> _restore() async {
    await ref.read(historyRepositoryProvider).restore(widget.version, ref.read(clockProvider)());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final version = widget.version;
    final current = ref.watch(itemProvider(version.itemId)).value?.item;
    final now = ref.read(clockProvider)();
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              child: Align(alignment: Alignment.centerLeft, child: _BackButton(onTap: () => Navigator.pop(context))),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 24),
                children: [
                  Text(versionTime(l, version.savedAt, now), style: text.titleSmall!.copyWith(color: Tokens.muted)),
                  const SizedBox(height: 6),
                  Text(version.title, style: text.headlineMedium!.copyWith(fontSize: 24, height: 1.15, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [ButtonSegment(value: false, label: Text(l.historyText)), ButtonSegment(value: true, label: Text(l.historyDiff))],
                    selected: {_diff},
                    onSelectionChanged: (picked) => setState(() => _diff = picked.single),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                    child: _diff && current != null
                        ? _DiffView(lines: diffLines(version.body, current.body))
                        : NoteBody(blocks: parseNoteBlocks(version.body), onToggle: (_) {}, onEdit: () {}, onLink: (_) {}),
                  ),
                  if (_diff) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(l.historyDiffHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(Space.screen, 8, Space.screen, 16 + bottom),
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _restore,
                  style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.onAccent, shape: const StadiumBorder()),
                  icon: Icon(symbolIcon('restore'), size: 20),
                  label: Text(l.historyRestore, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Разница строк: убранное зачёркнуто на красноватом, добавленное — на мятном,
/// с отметкой «−» и «+» слева, чтобы читалось и без цвета.
class _DiffView extends StatelessWidget {
  const _DiffView({required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.5, color: Tokens.onSurface);
    final mint = FolderPalette.colors['mint']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: switch (line.kind) {
                DiffKind.same => null,
                DiffKind.added => mint.withValues(alpha: Tokens.palette.isDark ? 0.16 : 0.32),
                DiffKind.removed => Tokens.error.withValues(alpha: 0.12),
              },
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text(
                    switch (line.kind) { DiffKind.same => '', DiffKind.added => '+', DiffKind.removed => '−' },
                    style: body.copyWith(fontWeight: FontWeight.w700, color: line.kind == DiffKind.added ? FolderPalette.ink(mint) : Tokens.error),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.text,
                    style: line.kind == DiffKind.removed
                        ? body.copyWith(color: Tokens.onSurfaceVariant, decoration: TextDecoration.lineThrough, decorationColor: Tokens.onSurfaceVariant)
                        : body,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
