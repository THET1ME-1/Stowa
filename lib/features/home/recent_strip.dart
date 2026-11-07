import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marked_text.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_title.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../item/adult_veil.dart';
import '../item/copying_bar.dart';

/// Ширина карточки в ленте вбок под картой.
const recentCardWidth = 148.0;

/// Полоса копирования встаёт под верхним краем, а не на подпись внизу.
const _barZone = 64.0;

/// Текст заметки под заголовком, без отступов: карточка узкая.
String notePreview(String body, {required String title}) => linesUnderTitle(body, title).map((line) => line.trim()).join('\n');

/// Высота карточки растёт вместе с системным шрифтом, иначе подпись режется.
double recentCardHeight(TextScaler scaler) {
  final title = scaler.scale(15) * 1.25 * 2;
  final caption = scaler.scale(12) * 1.35;
  return 128 + title + caption;
}

/// Карточка заметки в ленте вбок под картой: фото во всю карточку или сам текст.
class RecentCard extends StatelessWidget {
  const RecentCard({super.key, required this.item, required this.filesRoot, this.onTap});

  final ItemCard item;
  final Directory filesRoot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final where = Padding(padding: const EdgeInsets.only(top: 8), child: _Where(item: item, onPhoto: item.thumbPath != null));
    final thumb = item.thumbPath;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: recentCardWidth,
        decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.tile)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null) _PhotoFace(item: item, path: p.join(filesRoot.path, thumb), where: where) else _TextFace(item: item, where: where),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: _barZone,
              child: WithCopyingBar(itemId: item.id, copying: item.copying > 0, child: const SizedBox.expand()),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _titleStyle(TextTheme text) => text.titleSmall!.copyWith(fontSize: 15, height: 1.25, color: Tokens.onSurface);

/// Картинка или обложка на всю карточку, заголовок поверх затемнения снизу.
class _PhotoFace extends StatelessWidget {
  const _PhotoFace({required this.item, required this.path, required this.where});

  final ItemCard item;
  final String path;
  final Widget where;

  @override
  Widget build(BuildContext context) {
    final width = (recentCardWidth * MediaQuery.devicePixelRatioOf(context)).round();
    return Stack(
      fit: StackFit.expand,
      children: [
        AdultVeil(
          itemId: item.id,
          child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: width, errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHigh)),
        ),
        // белый заголовок читается на любой картинке: снизу затемнение цветом фона
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.35, 1],
              colors: [Tokens.containerLowest.withValues(alpha: 0), Tokens.containerLowest.withValues(alpha: 0.92)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.tile, Space.tile, Space.tile, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _titleStyle(Theme.of(context).textTheme)),
              where,
            ],
          ),
        ),
      ],
    );
  }
}

/// Заметка без картинки: заголовок и сколько влезает текста.
class _TextFace extends StatelessWidget {
  const _TextFace({required this.item, required this.where});

  final ItemCard item;
  final Widget where;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = notePreview(item.body, title: item.title);
    final iconName = switch (item.kind) {
      ItemKind.video => 'play_arrow',
      ItemKind.link => 'link',
      ItemKind.voice => 'graphic_eq',
      ItemKind.file => 'description',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, Space.tile, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (iconName != null) ...[
            ShapeBadge(
              shape: BadgeShape.cookie9,
              size: 34,
              color: Tokens.graphite,
              child: Icon(symbolIcon(iconName, filled: true), size: 18, color: Tokens.onSurface),
            ),
            const SizedBox(height: 12),
          ],
          Text(item.title, maxLines: preview.isEmpty ? 4 : 2, overflow: TextOverflow.ellipsis, style: _titleStyle(text)),
          // строк текста столько, сколько влезает в остаток карточки
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final line = MediaQuery.textScalerOf(context).scale(13) * 1.35;
                final lines = ((box.maxHeight - 6) / line).floor();
                if (preview.isEmpty || lines < 1) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: MarkedText.note(preview, maxLines: lines, style: text.bodySmall!.copyWith(fontSize: 13, height: 1.35, color: Tokens.onSurfaceVariant)),
                );
              },
            ),
          ),
          where,
        ],
      ),
    );
  }
}

/// Подпись внизу карточки: папка или «Без папки».
class _Where extends StatelessWidget {
  const _Where({required this.item, required this.onPhoto});

  final ItemCard item;

  /// Поверх картинки подпись светлее: серый на затемнении теряется.
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 12, color: onPhoto ? Tokens.onSurfaceVariant : Tokens.muted);
    final icon = item.folderName != null ? (item.folderIcon ?? 'folder') : 'inbox';
    final label = item.folderName ?? L.of(context).folderNone;
    return Row(
      children: [
        Icon(symbolIcon(icon), size: 15, color: item.folderColor == null ? style.color : (onPhoto ? item.folderColor : FolderPalette.ink(item.folderColor!))),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }
}
