import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../domain/models.dart';
import '../icons/icon_registry.dart';
import '../theme/tokens.dart';
import 'file_picture.dart';

/// Белая плитка тега: иконка из набора, эмодзи или своя картинка.
class TagTile extends StatelessWidget {
  const TagTile({super.key, required this.kind, required this.value, required this.filesRoot, this.size = 24, this.inverted = false, this.tonal = false});

  final TagIconKind kind;
  final String value;
  final Directory filesRoot;
  final double size;

  /// На белой подсветке плитка становится графитовой, иначе сливается.
  final bool inverted;

  /// В списке тегов плитка на подложке, а не белая: столбик белых квадратов перекрикивал имена.
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final fill = tonal ? Tokens.containerHighest : (inverted ? Tokens.graphite : Tokens.accent);
    final ink = tonal || inverted ? Tokens.onSurface : Tokens.onAccent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(size / 3)),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: switch (kind) {
        TagIconKind.symbol => Icon(
          symbolIcon(value, filled: true),
          size: size <= 30 ? size * 0.66 : size / 2,
          color: ink,
        ),
        TagIconKind.emoji => Text(value, style: TextStyle(fontSize: size * 0.58)),
        TagIconKind.image => FilePicture(File(p.join(filesRoot.path, value)), fit: BoxFit.cover, width: size, height: size),
      },
    );
  }
}
