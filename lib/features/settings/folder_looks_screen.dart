import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';
import '../folder/folder_look_screen.dart';
import 'settings_blocks.dart';

/// «Оформление → Папки»: все папки деревом, каждая своим значком. Касание открывает
/// «Название и вид» — тот же экран, что «⋮» в самой папке, только без захода в неё.
class FolderLooksScreen extends ConsumerWidget {
  const FolderLooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final folders = inTreeOrder(ref.watch(foldersProvider).value ?? const <FolderCard>[]);
    const outer = Radius.circular(Radii.card);
    const inner = Radius.circular(8);

    return Scaffold(
      key: const ValueKey('folder-looks'),
      body: SafeArea(
        // папок бывает сотня: строки строятся по мере прокрутки
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 6, Space.screen, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [SettingsHeader(l.foldersTab), const SizedBox(height: 10), SettingsHint(l.folderLooksHint)],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 40),
              sliver: SliverList.builder(
                itemCount: folders.length,
                // крайние строки скруглены крупно, средние слегка, как в группах настроек
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: index == 0 ? outer : inner, bottom: index == folders.length - 1 ? outer : inner),
                    child: _FolderRow(
                      key: ValueKey('folder-look-${folders[index].id}'),
                      folder: folders[index],
                      onTap: () => editFolderLook(context, ref.read(foldersRepositoryProvider), folders[index]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка папки: значок как на главной (её цвет, форма и иконка), имя, путь родителей.
class _FolderRow extends StatelessWidget {
  const _FolderRow({super.key, required this.folder, required this.onTap});

  final FolderCard folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final fill = folder.color;
    final under = [?folder.parentsLabel, if (folder.hidden) l.folderHiddenMark].join(' · ');
    return Material(
      color: Tokens.containerHigh,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              ShapeBadge(
                shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
                size: 44,
                color: fill,
                child: Icon(symbolIcon(folder.icon, filled: true), size: 22, color: inkOn(fill)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (under.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(under, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(symbolIcon('chevron_right'), size: 22, color: Tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}
