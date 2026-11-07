import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/tag_tile.dart';
import '../../data/repositories/tags_repository.dart';

/// Закреплённые теги одной строкой с прокруткой вбок: высота не растёт,
/// сколько тегов ни закрепи. Правый край тает, чтобы было видно, что строка листается.
/// В конце «+» — новый тег сразу на главную.
class PinnedTagsRow extends StatelessWidget {
  const PinnedTagsRow({super.key, required this.tags, required this.filesRoot, this.onTap, this.onAdd, this.addTooltip = ''});

  final List<TagCard> tags;
  final Directory filesRoot;
  final ValueChanged<TagCard>? onTap;
  final VoidCallback? onAdd;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(13) + 19;
    final size = height < 32 ? 32.0 : height;
    return SizedBox(
      height: size,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: Space.screen, right: 48),
            itemCount: tags.length + (onAdd == null ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) => index < tags.length
                ? _TagPill(tag: tags[index], filesRoot: filesRoot, onTap: onTap)
                : Tooltip(
                    message: addTooltip,
                    child: Material(
                      color: Tokens.containerHigh,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onAdd,
                        child: SizedBox.square(dimension: size, child: Icon(symbolIcon('add'), size: 18, color: Tokens.onSurfaceVariant)),
                      ),
                    ),
                  ),
          ),
          // край тает градиентом поверх, а не маской: маска перерисовывает слой при прокрутке
          Positioned(top: 0, bottom: 0, right: 0, width: 48, child: EdgeFade(color: Tokens.background, toRight: true)),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.filesRoot, this.onTap});

  final TagCard tag;
  final Directory filesRoot;
  final ValueChanged<TagCard>? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // долгое нажатие показывает имя тега
    return Tooltip(
      message: '#${tag.name}',
      child: Material(
        color: Tokens.containerHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap == null ? null : () => onTap!(tag),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: filesRoot),
                const SizedBox(width: 6),
                Text('${tag.count}', style: text.labelMedium!.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
