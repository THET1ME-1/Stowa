import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/models.dart';
import '../../domain/note_links.dart' show shownTitle;
import '../../l10n/app_localizations.dart';
import '../folder/folder_screen.dart';
import '../item/item_actions.dart';
import '../item/item_screen.dart';
import '../privacy/privacy_flows.dart';

Route<void> catalogRoute() => PageRouteBuilder(
  transitionDuration: Motion.long,
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => const CatalogScreen(),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

/// Высота строки дерева: плотно, как в Obsidian, но палец попадает.
const _folderRow = 48.0;
const _noteRow = 42.0;

/// Отступ заметок внутри папки: под значком папки.
const _branch = Space.screen + 26.0;

/// Шаг вложенной папки: её стрелка встаёт под значок родителя.
const _level = 26.0;

/// Каталог: все папки деревом, заметки внутри. Отдельный экран, не боковое меню.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

/// Ключ раскрытой папки; у «Без папки» своего id нет.
const _inbox = '';

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _open = <String>{};
  var _all = false;

  void _toggle(String key) => setState(() => _open.contains(key) ? _open.remove(key) : _open.add(key));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    final loose = ref.watch(folderItemsProvider(null)).value ?? const <ItemCard>[];
    // у папки число с вложенными: всего — по своим заметкам каждой, иначе посчитали бы дважды
    final total = folders.fold(0, (sum, folder) => sum + folder.ownCount) + loose.length;
    bool opened(String key) => _all || _open.contains(key);

    // дерево одним плоским списком: длинная папка строится по мере прокрутки
    final rows = <Widget>[];
    void branch(List<ItemCard> notes, int depth) {
      for (final (index, card) in notes.indexed) {
        rows.add(_NoteRow(card: card, last: index == notes.length - 1, depth: depth));
      }
    }

    // вложенные папки сперва, заметки папки под ними, как в дереве файлов
    final ids = {for (final folder in folders) folder.id};
    void folderBranch(String? parentId, int depth) {
      for (final folder in folders) {
        final parent = ids.contains(folder.parentId) ? folder.parentId : null;
        if (parent != parentId) continue;
        rows.add(
          _FolderRow(folder: folder, depth: depth, open: opened(folder.id), onTap: () => _toggle(folder.id), onOpen: () => Navigator.of(context).push(folderRoute(folder.id))),
        );
        if (!opened(folder.id)) continue;
        folderBranch(folder.id, depth + 1);
        branch(ref.watch(folderItemsProvider(folder.id)).value ?? const [], depth);
      }
    }

    folderBranch(null, 0);
    if (loose.isNotEmpty) {
      rows.add(_FolderRow(inboxCount: loose.length, open: opened(_inbox), onTap: () => _toggle(_inbox), onOpen: () => Navigator.of(context).push(folderRoute(null))));
      if (opened(_inbox)) branch(loose, 0);
    }
    // скрытые папки: строка входа, когда код заведён
    if (ref.watch(privacyLockProvider).value != null) {
      final hiddenOpen = ref.watch(hiddenOpenProvider).value ?? false;
      rows.add(
        _HiddenRow(
          open: hiddenOpen,
          onTap: () => hiddenOpen ? ref.read(privacyServiceProvider).close() : openHiddenFlow(context, ref),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen - 4, 0),
              child: Row(
                children: [
                  _HeaderButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  _HeaderButton(
                    icon: _all ? 'unfold_less' : 'unfold_more',
                    tooltip: _all ? l.catalogCollapse : l.catalogExpand,
                    onTap: () => setState(() {
                      _all = !_all;
                      _open.clear();
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 16, Space.screen, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(l.catalogTitle, style: text.headlineMedium!.copyWith(fontSize: 26, height: 1.1, letterSpacing: -0.6))),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('$total', style: text.titleSmall!.copyWith(fontFamily: 'Unbounded', fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.muted)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
                itemCount: rows.length,
                itemBuilder: (context, index) => rows[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Tokens.containerHigh, fixedSize: const Size.square(44)),
      icon: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurface),
    );
  }
}

/// Строка папки: стрелка, значок в цвет папки, имя, число заметок и переход в саму папку.
class _FolderRow extends StatelessWidget {
  const _FolderRow({this.folder, this.inboxCount = 0, this.depth = 0, required this.open, required this.onTap, required this.onOpen});

  /// null — «Без папки».
  final FolderCard? folder;

  /// Уровень вложенности: у верхней 0.
  final int depth;
  final int inboxCount;
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final folder = this.folder;
    // у «Без папки» значок серый: цвета у неё нет
    final badge = folder == null
        ? ShapeBadge(shape: BadgeShape.squircle, size: 26, color: Tokens.containerHighest, child: Icon(symbolIcon('inbox'), size: 15, color: Tokens.onSurfaceVariant))
        : ShapeBadge(
            shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
            size: 26,
            color: folder.color,
            child: Icon(symbolIcon(folder.icon, filled: true), size: 15, color: inkOn(folder.color)),
          );
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _folderRow,
        child: Row(
          children: [
            SizedBox(width: Space.screen - 6 + depth * _level),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: Motion.short,
              curve: Motion.emphasized,
              child: Icon(symbolIcon('chevron_right'), size: 20, color: Tokens.muted),
            ),
            const SizedBox(width: 4),
            badge,
            const SizedBox(width: 12),
            // имя и замок скрытой папки сразу за ним, число — у правого края
            Expanded(
              child: Row(
                children: [
                  Flexible(child: Text(folder?.name ?? l.folderNone, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall)),
                  if (folder?.hidden ?? false) ...[
                    const SizedBox(width: 6),
                    Icon(symbolIcon('lock'), size: 14, color: Tokens.muted, semanticLabel: l.folderHiddenMark),
                  ],
                ],
              ),
            ),
            Text('${folder?.count ?? inboxCount}', style: text.bodySmall!.copyWith(color: Tokens.muted, fontFeatures: const [FontFeature.tabularFigures()])),
            IconButton(
              tooltip: l.catalogOpenFolder,
              onPressed: onOpen,
              icon: Icon(symbolIcon('arrow_forward'), size: 18, color: Tokens.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// «Скрытые папки» внизу каталога: закрыты — открыть кодом или отпечатком, открыты — закрыть.
class _HiddenRow extends StatelessWidget {
  const _HiddenRow({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _folderRow,
        child: Row(
          children: [
            const SizedBox(width: Space.screen + 18),
            ShapeBadge(shape: BadgeShape.squircle, size: 26, color: Tokens.containerHighest, child: Icon(symbolIcon(open ? 'lock_open' : 'lock'), size: 15, color: Tokens.onSurfaceVariant)),
            const SizedBox(width: 12),
            Expanded(child: Text(open ? l.hiddenCloseRow : l.hiddenFolders, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall)),
            Icon(symbolIcon(open ? 'lock' : 'chevron_right'), size: 18, color: Tokens.onSurfaceVariant),
            const SizedBox(width: Space.screen),
          ],
        ),
      ),
    );
  }
}

/// Строка заметки под папкой: значок вида, заголовок, день. Слева линия ветки, как в дереве файлов.
class _NoteRow extends ConsumerWidget {
  const _NoteRow({required this.card, required this.last, this.depth = 0});

  final ItemCard card;

  /// Уровень папки, в которой лежит заметка: ветка сдвигается вместе с ней.
  final int depth;

  /// Последняя в папке: линия ветки кончается на ней.
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final icon = switch (card.kind) {
      ItemKind.link => 'link',
      ItemKind.video => 'play_circle',
      ItemKind.image => 'image',
      ItemKind.voice => 'mic',
      ItemKind.file => 'attach_file',
      ItemKind.note when card.body.contains('- [') => 'checklist',
      ItemKind.note => 'notes',
    };
    final now = ref.read(clockProvider)();
    final date = card.createdAt.year == now.year ? DateFormat.MMMd(l.localeName).format(card.createdAt) : DateFormat.yMMMd(l.localeName).format(card.createdAt);
    return InkWell(
      onTap: () => Navigator.of(context).push(itemRoute(card.id)),
      onLongPress: () => showItemActions(context, ref, card),
      child: SizedBox(
        height: _noteRow,
        child: Row(
          children: [
            // линия ветки под значком папки
            SizedBox(
              width: _branch + 18 + depth * _level,
              child: Align(
                // у последней половина линии сверху: ветка доходит до неё и кончается
                alignment: last ? AlignmentDirectional.topStart : AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(start: _branch + 8 + depth * _level),
                  child: SizedBox(
                    width: 1.5,
                    height: last ? _noteRow / 2 : _noteRow,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ColoredBox(color: card.folderColor == null ? Tokens.outline : FolderPalette.ink(card.folderColor!).withValues(alpha: 0.45), child: const SizedBox.expand()),
                    ),
                  ),
                ),
              ),
            ),
            Icon(symbolIcon(icon), size: 18, color: card.folderColor == null ? Tokens.muted : FolderPalette.ink(card.folderColor!)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(shownTitle(card.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurface)),
            ),
            const SizedBox(width: 8),
            Text(date, style: text.bodySmall!.copyWith(fontSize: 12, color: Tokens.muted)),
            const SizedBox(width: Space.screen),
          ],
        ),
      ),
    );
  }
}
