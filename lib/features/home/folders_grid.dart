import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/folders_repository.dart';

const _gap = 8.0;

/// Папки плиткой в две колонки. Папка с тремя и больше картинками встаёт
/// первой большой плиткой с мозаикой, рядом две обычные.
class FoldersGrid extends StatelessWidget {
  const FoldersGrid({super.key, required this.folders, required this.filesRoot, this.onOpen});

  final List<FolderCard> folders;
  final Directory filesRoot;
  final ValueChanged<FolderCard>? onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var rest = folders;
    if (folders.length >= 3 && folders.first.covers.length >= 3) {
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _tile(folders[0], big: true)),
          const SizedBox(width: _gap),
          Expanded(
            child: Column(children: [
              _tile(folders[1]),
              const SizedBox(height: _gap),
              _tile(folders[2]),
            ]),
          ),
        ]),
      ));
      rest = folders.sublist(3);
    }
    for (var index = 0; index < rest.length; index += 2) {
      final pair = rest.skip(index).take(2).toList();
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _tile(pair[0])),
          const SizedBox(width: _gap),
          Expanded(child: pair.length > 1 ? _tile(pair[1]) : const SizedBox()),
        ]),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: Column(children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: _gap),
          row,
        ],
      ]),
    );
  }

  Widget _tile(FolderCard folder, {bool big = false}) =>
      FolderTile(folder: folder, filesRoot: filesRoot, big: big, onTap: onOpen == null ? null : () => onOpen!(folder));
}

class FolderTile extends StatelessWidget {
  const FolderTile({super.key, required this.folder, required this.filesRoot, this.big = false, this.onTap});

  final FolderCard folder;
  final Directory filesRoot;
  final bool big;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle;
    final header = Row(children: [
      ShapeBadge(
        shape: shape,
        size: 40,
        color: big ? Tokens.accent : null,
        child: Icon(symbolIcon(folder.icon), size: 21, color: big ? Tokens.onAccent : Tokens.onSurface),
      ),
      const Spacer(),
      Text('${folder.count}', style: text.headlineSmall!.copyWith(fontSize: 20)),
    ]);
    final name = Text(folder.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleMedium!.copyWith(height: 1.2));
    final sub = folder.recentTitles.isEmpty
        ? null
        : Text(
            folder.recentTitles.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: Tokens.muted),
          );

    final Widget body;
    if (big) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 124, child: _Mosaic(paths: folder.covers, filesRoot: filesRoot)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(Space.tile),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              header,
              const Spacer(),
              const SizedBox(height: 12),
              name,
              if (sub != null) ...[const SizedBox(height: 2), sub],
            ]),
          ),
        ),
      ]);
    } else {
      body = Padding(
        padding: const EdgeInsets.all(Space.tile),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          header,
          if (folder.covers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Strip(paths: folder.covers, filesRoot: filesRoot),
          ],
          const SizedBox(height: 12),
          name,
          if (sub != null && folder.covers.isEmpty) ...[const SizedBox(height: 2), sub],
        ]),
      );
    }

    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 132),
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

Widget _photo(Directory root, String path, {int? cacheWidth}) => Image.file(
      File(p.join(root.path, path)),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => const ColoredBox(color: Tokens.containerHigh),
    );

class _Mosaic extends StatelessWidget {
  const _Mosaic({required this.paths, required this.filesRoot});

  final List<String> paths;
  final Directory filesRoot;

  @override
  Widget build(BuildContext context) {
    final width = (200 * MediaQuery.devicePixelRatioOf(context)).round();
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: _photo(filesRoot, paths[0], cacheWidth: width)),
      const SizedBox(width: 3),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _photo(filesRoot, paths[1], cacheWidth: width ~/ 2)),
          const SizedBox(height: 3),
          Expanded(child: _photo(filesRoot, paths[2], cacheWidth: width ~/ 2)),
        ]),
      ),
    ]);
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.paths, required this.filesRoot});

  final List<String> paths;
  final Directory filesRoot;

  @override
  Widget build(BuildContext context) {
    final width = (60 * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      height: 40,
      child: Row(children: [
        for (final (index, path) in paths.take(3).indexed) ...[
          if (index > 0) const SizedBox(width: 4),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: _photo(filesRoot, path, cacheWidth: width))),
        ],
        for (var index = paths.length; index < 3; index++) ...[const SizedBox(width: 4), const Expanded(child: SizedBox())],
      ]),
    );
  }
}
