/// Журнал правок хранилища, как `git log`: что, когда и с какого устройства менялось. Правки
/// одного файла подряд с одного устройства — одной строкой, касание открывает историю.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/cloud_history.dart';
import '../composer/panel_text.dart';
import '../item/history_screen.dart';
import 'cloud_trash.dart' show deletedName;
import 'settings_blocks.dart';

Route<void> syncLogRoute() => settingsPageRoute(const SyncLogScreen());

/// Строка журнала: одна правка или несколько подряд.
class LogRow {
  const LogRow({required this.last, required this.from, this.edits = 1});

  /// Самая свежая правка строки.
  final CloudVersion last;
  final DateTime from;
  final int edits;
}

/// Журнал ([entries] свежие первыми) — в строки: тот же файл, то же устройство, перерыв
/// меньше [gap]. Удаление — всегда своя строка.
List<LogRow> groupLog(List<LogEntry> entries, {Duration gap = const Duration(minutes: 10)}) {
  final rows = <LogRow>[];
  for (final entry in entries) {
    final version = entry.version;
    final open = rows.isEmpty ? null : rows.last;
    if (open != null &&
        !version.deleted &&
        !open.last.deleted &&
        open.last.path == version.path &&
        open.last.device == version.device &&
        open.from.difference(version.at) < gap) {
      rows[rows.length - 1] = LogRow(last: open.last, from: version.at, edits: open.edits + 1);
    } else {
      rows.add(LogRow(last: version, from: version.at));
    }
  }
  return rows;
}

class SyncLogScreen extends ConsumerStatefulWidget {
  const SyncLogScreen({super.key});

  @override
  ConsumerState<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends ConsumerState<SyncLogScreen> {
  final _entries = <LogEntry>[];
  String? _next;
  var _loading = true;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    // Riverpod 3 ставит на паузу провайдер без слушателей: `.future` у неслушаемой истории
    // ждал бы вечно. Экран слушает её, пока открыт
    ref.listenManual(cloudHistoryProvider, (_, _) {});
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final history = await ref.read(cloudHistoryProvider.future);
      if (history == null) throw StateError('не вошли');
      final (page, next) = await history.log(after: _next, limit: 200);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _next = next;
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(LogRow row) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final item = await ref.read(historyRepositoryProvider).itemAt(row.last.path);
    if (!mounted) return;
    if (item == null) {
      showNote(messenger, l.syncLogGone);
      return;
    }
    final document = item.kind == ItemKind.canvas || item.kind == ItemKind.base || item.kind == ItemKind.drawing;
    await Navigator.of(context).push(historyRoute(item.id, document: document));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.read(clockProvider)();
    final rows = groupLog(_entries);
    final days = <(String, List<LogRow>)>[];
    for (final row in rows) {
      final day = shortDate(l, row.last.at, now);
      final label = '${day[0].toUpperCase()}${day.substring(1)}';
      if (days.isEmpty || days.last.$1 != label) days.add((label, []));
      days.last.$2.add(row);
    }
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(48)),
                        icon: Icon(symbolIcon('arrow_back'), size: 22, color: Tokens.onSurface),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.syncLogTitle, style: text.titleLarge!.copyWith(fontSize: 18))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(l.syncLogHint, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4)),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(symbolIcon('cloud_off'), size: 16, color: Tokens.muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l.historyOffline, style: text.bodySmall!.copyWith(color: Tokens.muted))),
                      ],
                    ),
                  ],
                  if (!_loading && !_failed && rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Center(child: Text(l.syncLogEmpty, style: text.titleMedium!.copyWith(color: Tokens.onSurfaceVariant))),
                    ),
                ],
              ),
            ),
            for (final (label, dayRows) in days)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 20, Space.screen, 0),
                sliver: SliverList.builder(
                  itemCount: dayRows.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(label, style: text.titleSmall!.copyWith(color: Tokens.muted, fontWeight: FontWeight.w600)),
                      );
                    }
                    final row = dayRows[index - 1];
                    final first = index == 1, last = index == dayRows.length;
                    return Padding(
                      padding: EdgeInsets.only(bottom: last ? 0 : 4),
                      child: _LogTile(
                        row: row,
                        radius: BorderRadius.vertical(top: Radius.circular(first ? Radii.card : 8), bottom: Radius.circular(last ? Radii.card : 8)),
                        onTap: _opens(row.last.path) ? () => _open(row) : null,
                      ),
                    );
                  },
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 24 + bottom),
              sliver: SliverList.list(
                children: [
                  if (_loading) const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
                  if (!_loading && _next != null)
                    Center(
                      child: TextButton.icon(onPressed: _load, icon: Icon(symbolIcon('expand_more'), size: 20), label: Text(l.historyEarlier)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// У какой правки есть экран истории: заметка, холст, база, рисунок. У фото и прочих файлов —
/// нет, строка журнала просто рассказывает.
bool _opens(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.md') || lower.endsWith('.canvas') || lower.endsWith('.base');
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.row, required this.radius, this.onTap});

  final LogRow row;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final version = row.last;
    final hm = DateFormat.Hm(l.localeName);
    final time = row.edits > 1 ? '${hm.format(row.from)}–${hm.format(version.at)}' : hm.format(version.at);
    final folder = p.posix.dirname(version.path);
    final note = [
      ?version.device,
      if (row.edits > 1) keepTogether(l.historyEdits(row.edits)),
      if (version.deleted) l.syncLogDeleted,
      if (folder != '.') folder,
    ].join(' · ');
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: radius),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Tokens.graphite, shape: BoxShape.circle),
            child: Icon(symbolIcon(version.deleted ? 'delete' : 'edit_note'), size: 20, color: Tokens.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deletedName(version.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [time, if (note.isNotEmpty) note].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          if (onTap != null) Icon(symbolIcon('chevron_right'), size: 20, color: Tokens.muted),
        ],
      ),
    );
    return onTap == null ? tile : Pressable(onTap: onTap, radius: radius, child: tile);
  }
}
