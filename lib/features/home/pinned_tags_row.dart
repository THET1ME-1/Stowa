import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/tag_tile.dart';
import '../../data/repositories/tags_repository.dart';

/// Закреплённые теги одной строкой с прокруткой вбок: высота не растёт,
/// сколько тегов ни закрепи. Правый край тает, чтобы было видно, что строка листается.
class PinnedTagsRow extends StatelessWidget {
  const PinnedTagsRow({super.key, required this.tags, required this.filesRoot, this.onTap});

  final List<TagCard> tags;
  final Directory filesRoot;
  final ValueChanged<TagCard>? onTap;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(13) + 19;
    return SizedBox(
      height: height < 32 ? 32 : height,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.86, 1],
        ).createShader(bounds),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.screen),
          itemCount: tags.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) => _TagPill(tag: tags[index], filesRoot: filesRoot, onTap: onTap),
        ),
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
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TagTile(kind: tag.iconKind, value: tag.iconValue, filesRoot: filesRoot),
              const SizedBox(width: 6),
              Text('${tag.count}', style: text.labelMedium!.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
