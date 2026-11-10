import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../item/item_screen.dart';
import 'privacy_flows.dart';

/// Касание напоминания скрытой заметки: открыть скрытое кодом или отпечатком, потом заметку.
Route<void> hiddenItemRoute(String id) => MaterialPageRoute(builder: (context) => _HiddenItem(id: id));

class _HiddenItem extends ConsumerStatefulWidget {
  const _HiddenItem({required this.id});

  final String id;

  @override
  ConsumerState<_HiddenItem> createState() => _HiddenItemState();
}

class _HiddenItemState extends ConsumerState<_HiddenItem> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final opened = await openHiddenFlow(context, ref);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      opened ? navigator.pushReplacement(itemRoute(widget.id)) : navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
