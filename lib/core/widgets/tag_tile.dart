import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../domain/models.dart';
import '../icons/icon_registry.dart';
import '../theme/tokens.dart';

/// Белая плитка тега: иконка из набора, эмодзи или своя картинка.
class TagTile extends StatelessWidget {
  const TagTile({super.key, required this.kind, required this.value, required this.filesRoot, this.size = 24});

  final TagIconKind kind;
  final String value;
  final Directory filesRoot;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(size / 3)),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: switch (kind) {
        TagIconKind.symbol => Icon(symbolIcon(value, filled: true), size: size * 0.66, color: Tokens.onAccent),
        TagIconKind.emoji => Text(value, style: TextStyle(fontSize: size * 0.58)),
        TagIconKind.image => Image.file(File(p.join(filesRoot.path, value)), fit: BoxFit.cover, width: size, height: size),
      },
    );
  }
}
