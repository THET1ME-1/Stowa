import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/note_blocks.dart';
import '../../domain/note_links.dart' show shownTitle;
import '../../domain/text_diff.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/cloud_history.dart';
import '../composer/panel_text.dart';
import '../subscription/paywall_screen.dart';
import '../subscription/subscribe_card.dart' show AccentCard;
import 'note_body.dart';
import 'note_history.dart';

/// История вырастает из нажатой кнопки, как страница заметки. Вернули версию — экран отдаёт true.
/// [document] — холст, база или рисунок: возвращается весь файл, снимков устройства у них нет.
Route<bool> historyRoute(String itemId, {bool document = false}) => MaterialPageRoute(builder: (_) => HistoryScreen(itemId: itemId, document: document));

/// «Сегодня, 14:05», «7 нояб., 10:20».
String versionTime(L l, DateTime at, DateTime now) {
  final day = shortDate(l, at, now);
  return '${day[0].toUpperCase()}${day.substring(1)}, ${DateFormat.Hm(l.localeName).format(at)}';
}

/// «14:05» или «14:05–14:32» для сеанса правки.
String _clock(L l, HistoryEntry entry) {
  final to = DateFormat.Hm(l.localeName).format(entry.at);
  final from = entry.from;
  return from == null ? to : '${DateFormat.Hm(l.localeName).format(from)}–$to';
}

/// «+3 −1» от [older] к [newer]; тот же текст — «Текст тот же».
String changesLabel(L l, String older, String newer) {
  final counts = diffCounts(diffLines(older, newer));
  if (counts.added == 0 && counts.removed == 0) return l.historyNoChanges;
  return '+${counts.added} −${counts.removed}';
}

/// История заметки: «Сейчас», потом версии по дням, новые сверху. С Stowa Sync — правки со
/// всех устройств сеансами (подряд, с одного устройства), касание сеанса раскрывает каждую
/// правку. Без подписки или без сети — снимки этого устройства.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.itemId, this.document = false});

  final String itemId;

  /// Холст, база или рисунок: в строках — то, что в нём ищется, возврат меняет весь файл.
  /// Снимки устройства у документа не годятся: они помнят только текст для поиска.
  final bool document;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  var _budget = historyBudget;

  /// Раскрытые сеансы: номер ревизии конца сеанса.
  final _open = <int>{};

  (String, int, bool) get _key => (widget.itemId, _budget, widget.document);

  Future<void> _openVersion(HistoryEntry entry, HistoryEntry? previous) async {
    final cloudOn = ref.read(cloudNoteHistoryProvider(_key)).value?.access == CloudAccess.on;
    final restored = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => VersionScreen(itemId: widget.itemId, entry: entry, previous: previous, cloudOn: cloudOn, document: widget.document)));
    if (restored == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final item = ref.watch(itemProvider(widget.itemId)).value?.item;
    final local = widget.document ? const <NoteVersion>[] : ref.watch(noteVersionsProvider(widget.itemId)).value ?? const <NoteVersion>[];
    final cloudState = ref.watch(cloudNoteHistoryProvider(_key));
    final cloud = cloudState.value;
    final loading = cloudState.isLoading && cloud == null;
    final access = cloud?.access;
    final now = ref.read(clockProvider)();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final currentPath = ref.watch(_pathProvider(widget.itemId)).value;
    final entries = item == null ? const <HistoryEntry>[] : mergeHistory(title: item.title, body: item.body, local: local, cloud: cloud?.entries ?? const []);

    // строки по дням: заголовок дня и сцепленные блоки
    final days = <(String, List<int>)>[];
    for (final (index, entry) in entries.indexed) {
      final day = shortDate(l, entry.at, now);
      final label = '${day[0].toUpperCase()}${day.substring(1)}';
      if (days.isEmpty || days.last.$1 != label) days.add((label, []));
      days.last.$2.add(index);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              sliver: SliverList.list(
                children: [
                  Align(alignment: Alignment.centerLeft, child: _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context))),
                  const SizedBox(height: 16),
                  Text(l.historyTitle, style: text.headlineMedium!.copyWith(fontSize: 26, height: 1.1, letterSpacing: -0.6)),
                  if (item != null) ...[
                    const SizedBox(height: 4),
                    Text(shownTitle(item.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
                  ],
                  if (access == CloudAccess.offline) ...[
                    const SizedBox(height: 12),
                    _QuietLine(icon: 'cloud_off', text: l.historyOffline),
                  ],
                  const SizedBox(height: 20),
                  if (item != null)
                    _VersionRow(
                      key: const ValueKey('history-now'),
                      time: l.historyNow,
                      preview: _preview(item.body, item.title),
                      note: versionTime(l, item.updatedAt, now),
                      kind: _RowKind.current,
                      radius: BorderRadius.circular(Radii.card),
                    ),
                  if (loading) ...[const SizedBox(height: 16), const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))],
                ],
              ),
            ),
            for (final (label, indexes) in days)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.screen, 20, Space.screen, 0),
                sliver: SliverList.builder(
                  itemCount: indexes.length + 1,
                  itemBuilder: (context, position) {
                    if (position == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(label, style: text.titleSmall!.copyWith(color: Tokens.muted, fontWeight: FontWeight.w600)),
                      );
                    }
                    final index = indexes[position - 1];
                    final entry = entries[index];
                    final previous = index + 1 < entries.length ? entries[index + 1] : null;
                    final first = position == 1, last = position == indexes.length;
                    final session = entry.session;
                    final opened = session != null && _open.contains(entry.cloud!.rev);
                    return Padding(
                      padding: EdgeInsets.only(bottom: last ? 0 : 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _VersionRow(
                            time: _clock(l, entry),
                            preview: _preview(entry.body, entry.title),
                            note: [
                              // «только на этом устройстве» имеет смысл, только когда рядом облако
                              if (!entry.localOnly) ?entry.device else if (access == CloudAccess.on) l.historyLocalOnly,
                              if (entry.edits > 1) l.historyEdits(entry.edits),
                              if (previous != null) changesLabel(l, previous.body, entry.body),
                            ].join(' · '),
                            moved: entry.path != null && currentPath != null && entry.path != currentPath ? l.historyMoved(p.posix.withoutExtension(entry.path!)) : null,
                            kind: entry.localOnly && access == CloudAccess.on ? _RowKind.local : _RowKind.cloud,
                            radius: BorderRadius.vertical(top: Radius.circular(first ? Radii.card : 8), bottom: Radius.circular(last && !opened ? Radii.card : 8)),
                            expanded: session != null && entry.edits > 1 ? opened : null,
                            onExpand: () => setState(() => opened ? _open.remove(entry.cloud!.rev) : _open.add(entry.cloud!.rev)),
                            onTap: () => _openVersion(entry, previous),
                          ),
                          if (opened)
                            _SessionEdits(
                              session: session,
                              previous: previous,
                              last: last,
                              document: widget.document,
                              onOpen: (version, edit, before) => _openVersion(edit, before),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 24 + bottom),
              sliver: SliverList.list(
                children: [
                  if (cloud?.more ?? false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _budget *= 2),
                          icon: Icon(symbolIcon('expand_more'), size: 20),
                          label: Text(l.historyEarlier),
                        ),
                      ),
                    ),
                  if (access == CloudAccess.signedOut || access == CloudAccess.noSubscription)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AccentCard(
                        key: const ValueKey('history-promo'),
                        icon: 'history',
                        title: l.historyPromoTitle,
                        hint: l.historyPromoHint,
                        onTap: () => Navigator.of(context).push(paywallRoute()),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(access == CloudAccess.on ? l.historyCloudHint : l.historyHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
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

/// Путь файла заметки: подпись «Тогда лежала: …» у версий с другим путём.
final _pathProvider = FutureProvider.autoDispose.family<String?, String>((ref, itemId) => ref.watch(historyRepositoryProvider).pathOf(itemId));

// первая строка с текстом, без значков разметки
String _preview(String body, String title) {
  for (final block in parseNoteBlocks(body)) {
    final line = switch (block) {
      ParagraphBlock(:final text) || HeadingBlock(:final text) || BulletBlock(:final text) || NumberedBlock(:final text) || CheckBlock(:final text) || QuoteBlock(:final text) => text,
      ImageBlock() => '',
      // у выноски первая строка — её заголовок
      CalloutBlock(:final shownTitle) => shownTitle,
      // у таблицы — шапка через «·»
      TableBlock(:final header) => header.join(' · '),
      // первая строка кода, без подсветки и разметки
      CodeBlock(:final code) => code.split('\n').firstWhere((one) => one.trim().isNotEmpty, orElse: () => ''),
      MathBlock(:final tex) => tex.split('\n').first,
    };
    // абзац бывает в несколько строк, и первая из них — сам заголовок
    for (final one in line.split('\n')) {
      final plain = parseInline(one).map((piece) => piece.text).join().trim();
      if (plain.isNotEmpty && plain != title) return plain;
    }
  }
  return title;
}

/// Правки внутри раскрытого сеанса, кроме последней — она сама строка сеанса. Тексты
/// приходят с сервера, когда сеанс раскрыли.
class _SessionEdits extends ConsumerWidget {
  const _SessionEdits({required this.session, required this.previous, required this.last, required this.onOpen, this.document = false});

  final VersionSession session;
  final bool document;

  /// Строка старше сеанса: с ней сравнивается первая правка.
  final HistoryEntry? previous;
  final bool last;
  final void Function(CloudVersion version, HistoryEntry edit, HistoryEntry? before) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final history = ref.watch(cloudHistoryProvider).value;
    final versions = session.versions.skip(1).toList();
    return FutureBuilder<List<HistoryEntry>>(
      future: history == null ? Future.value(const []) : _load(history),
      builder: (context, snapshot) {
        final edits = snapshot.data;
        if (edits == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: snapshot.hasError ? _QuietLine(icon: 'error', text: l.historyLoadFailed) : const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, edit) in edits.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _EditRow(
                  time: DateFormat.Hm(l.localeName).format(edit.at),
                  note: index + 1 < edits.length ? changesLabel(l, edits[index + 1].body, edit.body) : (previous == null ? null : changesLabel(l, previous!.body, edit.body)),
                  radius: BorderRadius.vertical(top: const Radius.circular(8), bottom: Radius.circular(last && index == edits.length - 1 ? Radii.card : 8)),
                  onTap: () => onOpen(versions[index], edit, index + 1 < edits.length ? edits[index + 1] : previous),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<List<HistoryEntry>> _load(CloudHistory history) async => [
    for (final version in session.versions.skip(1))
      if (noteTextOf(await history.text(version), version, document: document) case final text)
        HistoryEntry(title: text.title, body: text.body, at: version.at, device: version.device, cloud: version, path: version.path),
  ];
}

enum _RowKind { current, cloud, local }

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(48)),
      icon: Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: Tokens.muted, height: 1.35);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(symbolIcon(icon), size: 16, color: Tokens.muted)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Строка версии: время, первая строка текста, откуда и что поменялось. Блоки списка сцеплены,
/// как в настройках: края скруглены только у первого и последнего блока дня.
class _VersionRow extends StatelessWidget {
  const _VersionRow({
    super.key,
    required this.time,
    required this.preview,
    required this.radius,
    required this.kind,
    this.note,
    this.moved,
    this.expanded,
    this.onExpand,
    this.onTap,
  });

  final String time;
  final String preview;
  final String? note;

  /// «Тогда лежала: …» — версия под другим именем или в другой папке.
  final String? moved;
  final _RowKind kind;
  final BorderRadius radius;

  /// Сеанс из нескольких правок: раскрыт ли. null — раскрывать нечего.
  final bool? expanded;
  final VoidCallback? onExpand;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final current = kind == _RowKind.current;
    final small = text.bodySmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]);
    final row = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(color: current ? Tokens.containerHigh : Tokens.container, borderRadius: radius),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: current ? Tokens.accent : Tokens.graphite, shape: BoxShape.circle),
            child: Icon(
              symbolIcon(switch (kind) {
                _RowKind.current => 'edit_note',
                _RowKind.cloud => 'history',
                _RowKind.local => 'smartphone',
              }),
              size: 20,
              color: current ? Tokens.onAccent : Tokens.onSurface,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                if (note case final note? when note.isNotEmpty) ...[const SizedBox(height: 2), Text(note, style: small)],
                if (moved case final moved?) ...[const SizedBox(height: 2), Text(moved, maxLines: 1, overflow: TextOverflow.ellipsis, style: small)],
              ],
            ),
          ),
          if (expanded case final open?)
            IconButton(
              tooltip: open ? l.historySessionClose : l.historySessionOpen,
              onPressed: onExpand,
              icon: AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic, child: Icon(symbolIcon('expand_more'), size: 22, color: Tokens.muted)),
            )
          else if (onTap != null)
            Padding(padding: const EdgeInsets.only(right: 4), child: Icon(symbolIcon('chevron_right'), size: 20, color: Tokens.muted)),
        ],
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, radius: radius, child: row);
  }
}

/// Правка внутри раскрытого сеанса: время и что она поменяла.
class _EditRow extends StatelessWidget {
  const _EditRow({required this.time, required this.radius, required this.onTap, this.note});

  final String time;
  final String? note;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      radius: radius,
      child: Container(
        padding: const EdgeInsets.fromLTRB(70, 10, 12, 10),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: radius),
        child: Row(
          children: [
            Text(time, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 12),
            Expanded(child: Text(note ?? '', style: text.bodySmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()]))),
            Icon(symbolIcon('chevron_right'), size: 18, color: Tokens.muted),
          ],
        ),
      ),
    );
  }
}

enum _VersionView { text, changes, now }

/// Версия целиком: текст, что поменяла эта правка, разница с нынешним; внизу «Вернуть эту
/// версию». Возврат — новая правка: нынешний текст сперва ложится снимком.
class VersionScreen extends ConsumerStatefulWidget {
  const VersionScreen({super.key, required this.itemId, required this.entry, this.previous, this.cloudOn = false, this.document = false});

  final String itemId;
  final HistoryEntry entry;

  /// Рядом история из облака: снимок этого устройства подписан.
  final bool cloudOn;

  /// Холст, база или рисунок: возвращается файл версии целиком.
  final bool document;

  /// Версия до этой: с ней сравнивается «Изменения». null — старше версий нет.
  final HistoryEntry? previous;

  @override
  ConsumerState<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends ConsumerState<VersionScreen> {
  late var _view = widget.previous == null ? _VersionView.now : _VersionView.changes;

  Future<void> _restore() async {
    final entry = widget.entry;
    if (widget.document) {
      await _restoreFile(entry.cloud!);
      return;
    }
    await ref.read(historyRepositoryProvider).restoreText(widget.itemId, title: entry.title, body: entry.body, at: ref.read(clockProvider)());
    if (mounted) Navigator.pop(context, true);
  }

  /// Холст, база, рисунок: файл версии встаёт на место нынешнего. «Отменить» кладёт прежний
  /// файл обратно — он мог ещё не уйти на сервер, поэтому берётся с диска, а не из облака.
  Future<void> _restoreFile(CloudVersion version) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final history = await ref.read(cloudHistoryProvider.future);
    final path = await ref.read(historyRepositoryProvider).pathOf(widget.itemId);
    if (history == null || path == null) return;
    final sync = ref.read(syncServiceProvider);
    final List<int>? before;
    try {
      before = await sync.replaceFile(path, history.parts(version));
    } on Object {
      if (mounted) showNote(messenger, l.historyLoadFailed);
      return;
    }
    if (before == null) {
      if (mounted) showNote(messenger, l.historyLoadFailed);
      return;
    }
    if (mounted) Navigator.pop(context, true);
    showUndo(messenger, message: l.historyRestored, label: l.undo, onUndo: () => sync.replaceFile(path, Stream.value(before!)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.body));
    if (mounted) showNote(ScaffoldMessenger.of(context), L.of(context).historyCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final entry = widget.entry;
    final full = ref.watch(itemProvider(widget.itemId)).value;
    final current = full?.item;
    final filesRoot = ref.watch(filesRootProvider);
    final now = ref.read(clockProvider)();
    // картинка версии — тот же файл вложения, если он ещё при заметке
    Widget image(String name) {
      final paths = [for (final file in full?.attachments ?? const <Attachment>[]) file.path];
      final path = embedPath(name, paths);
      if (path == null) return MissingImage(name: name);
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.tile),
        child: FilePicture(
          File(p.join(filesRoot.path, path)),
          fit: BoxFit.cover,
          cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) => MissingImage(name: name),
        ),
      );
    }

    final origin = [
      if (!entry.localOnly) ?entry.device else if (widget.cloudOn) l.historyLocalOnly,
      if (entry.edits > 1) l.historyEdits(entry.edits),
    ].join(' · ');
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              child: Row(
                children: [
                  _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  _RoundButton(icon: 'content_copy', tooltip: l.historyCopy, onTap: _copy),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 24),
                children: [
                  Text(entry.from == null ? versionTime(l, entry.at, now) : '${versionTime(l, entry.from!, now)}–${DateFormat.Hm(l.localeName).format(entry.at)}', style: text.titleSmall!.copyWith(color: Tokens.muted)),
                  if (origin.isNotEmpty) Text(origin, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                  const SizedBox(height: 6),
                  Text(shownTitle(entry.title), style: text.headlineMedium!.copyWith(fontSize: 24, height: 1.15, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  SegmentedButton<_VersionView>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: _VersionView.text, label: Text(l.historyText)),
                      if (widget.previous != null) ButtonSegment(value: _VersionView.changes, label: Text(l.historyChanges)),
                      ButtonSegment(value: _VersionView.now, label: Text(l.historyDiff)),
                    ],
                    selected: {_view},
                    onSelectionChanged: (picked) => setState(() => _view = picked.single),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                    child: switch (_view) {
                      _VersionView.changes => _DiffView(rows: diffRows(widget.previous!.body, entry.body)),
                      _VersionView.now when current != null => _DiffView(rows: diffRows(entry.body, current.body)),
                      _ => NoteBody(blocks: parseNoteBlocks(entry.body), onToggle: (_) {}, onEdit: () {}, onLink: (_) {}, image: image),
                    },
                  ),
                  if (_view != _VersionView.text) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(_view == _VersionView.changes ? l.historyChangesHint : l.historyDiffHint, style: text.bodySmall!.copyWith(color: Tokens.muted, height: 1.4)),
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

/// Разница строк: убранное зачёркнуто на красноватом, добавленное — на мятном, с отметкой
/// «−» и «+» слева, чтобы читалось и без цвета. В паре изменённых строк сами слова
/// подсвечены плотнее.
class _DiffView extends StatelessWidget {
  const _DiffView({required this.rows});

  final List<DiffRow> rows;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.5, color: Tokens.onSurface);
    final mint = FolderPalette.colors['mint']!;
    final dark = Tokens.palette.isDark;
    Color? lineTint(DiffKind kind) => switch (kind) {
      DiffKind.same => null,
      DiffKind.added => mint.withValues(alpha: dark ? 0.16 : 0.32),
      DiffKind.removed => Tokens.error.withValues(alpha: 0.12),
    };
    Color wordTint(DiffKind kind) => kind == DiffKind.added ? mint.withValues(alpha: dark ? 0.42 : 0.7) : Tokens.error.withValues(alpha: 0.3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: lineTint(row.kind), borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  child: Text(
                    switch (row.kind) { DiffKind.same => '', DiffKind.added => '+', DiffKind.removed => '−' },
                    style: body.copyWith(fontWeight: FontWeight.w700, color: row.kind == DiffKind.added ? FolderPalette.ink(mint) : Tokens.error),
                  ),
                ),
                Expanded(
                  child: switch (embedLine.firstMatch(row.text)) {
                    // картинка — значком и именем файла, без скобок разметки
                    final embed? => Row(
                      children: [
                        Icon(symbolIcon('image'), size: 18, color: Tokens.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            embed.group(1)!.trim().split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body.copyWith(
                              color: Tokens.muted,
                              decoration: row.kind == DiffKind.removed ? TextDecoration.lineThrough : null,
                              decorationColor: Tokens.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _ when row.pieces != null => Text.rich(
                      TextSpan(
                        children: [
                          for (final piece in row.pieces!)
                            TextSpan(
                              text: piece.text,
                              style: piece.changed
                                  ? body.copyWith(
                                      backgroundColor: wordTint(row.kind),
                                      decoration: row.kind == DiffKind.removed ? TextDecoration.lineThrough : null,
                                      decorationColor: Tokens.onSurface,
                                    )
                                  : body.copyWith(color: row.kind == DiffKind.removed ? Tokens.onSurfaceVariant : null),
                            ),
                        ],
                      ),
                    ),
                    _ => Text(
                      row.text,
                      style: row.kind == DiffKind.removed
                          ? body.copyWith(color: Tokens.onSurfaceVariant, decoration: TextDecoration.lineThrough, decorationColor: Tokens.onSurfaceVariant)
                          : body,
                    ),
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
