import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/tags_repository.dart';
import '../../domain/models.dart';

/// Закреплённые теги одной строкой с прокруткой вбок: высота не растёт,
/// сколько тегов ни закрепи. Правый край тает, чтобы было видно, что строка листается.
class PinnedTagsRow extends StatelessWidget {
  const PinnedTagsRow({super.key, required this.tags, required this.filesRoot, this.onTap});

  final List<PinnedTag> tags;
  final Directory filesRoot;
  final ValueChanged<PinnedTag>? onTap;

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

  final PinnedTag tag;
  final Directory filesRoot;
  final ValueChanged<PinnedTag>? onTap;

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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: _icon(),
              ),
              const SizedBox(width: 6),
              Text('${tag.count}', style: text.labelMedium!.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    return switch (tag.iconKind) {
      TagIconKind.symbol => Icon(symbolIcon(tag.iconValue, filled: true), size: 16, color: Tokens.onAccent),
      TagIconKind.emoji => Text(tag.iconValue, style: const TextStyle(fontSize: 14)),
      TagIconKind.image => Image.file(File(p.join(filesRoot.path, tag.iconValue)), fit: BoxFit.cover, width: 24, height: 24),
    };
  }
}
