import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/hints.dart';
import '../../l10n/app_localizations.dart';
import '../icons/icon_registry.dart';
import '../theme/tokens.dart';

/// Подсказка по месту: одна фраза пилюлей с «×». Показывается при первых трёх заходах на экран
/// или до «×». Решение «показывать» принимается при входе на экран и до ухода с него не меняется:
/// иначе подсказка пропадала бы посреди чтения, как только засчитался показ.
/// [when] — условие экрана («от двух папок», «пока нет ключа»): не выполнено — показ не тратится.
class HintBanner extends ConsumerStatefulWidget {
  const HintBanner({super.key, required this.tip, this.when = true, this.padding = EdgeInsets.zero});

  final Tip tip;
  final bool when;
  final EdgeInsets padding;

  @override
  ConsumerState<HintBanner> createState() => _HintBannerState();
}

class _HintBannerState extends ConsumerState<HintBanner> {
  /// null — ещё не решено (условие экрана не выполнено или состояние не пришло).
  bool? _shown;
  var _closed = false;

  void _decide(HintsState state) {
    if (_shown != null || !widget.when) return;
    _shown = tipVisible(state, widget.tip);
    if (_shown!) ref.read(hintsRepositoryProvider).tipShown(widget.tip).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hintsProvider).value;
    if (state != null) _decide(state);
    if (_shown != true || _closed || state == null || state.off) return const SizedBox.shrink();
    final l = L.of(context);
    return Padding(
      padding: widget.padding,
      child: Container(
        key: ValueKey('hint-${widget.tip.name}'),
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            Icon(symbolIcon('tips_and_updates', filled: true), size: 18, color: Tokens.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tipText(l, widget.tip), style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 14, height: 1.35, color: Tokens.onSurface)),
            ),
            IconButton(
              key: const ValueKey('hint-close'),
              tooltip: l.tipClose,
              onPressed: () {
                setState(() => _closed = true);
                ref.read(hintsRepositoryProvider).closeTip(widget.tip).ignore();
              },
              icon: Icon(symbolIcon('close'), size: 18, color: Tokens.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String tipText(L l, Tip tip) => switch (tip) {
  Tip.noteBar => l.tipNoteBar,
  Tip.longPress => l.tipLongPress,
  Tip.catalog => l.tipCatalog,
  Tip.folderMenu => l.tipFolderMenu,
  Tip.sort => l.tipSort,
  Tip.canvas => l.tipCanvas,
  Tip.base => l.tipBase,
  Tip.aiKey => l.tipAiKey,
  Tip.edge => l.tipEdge,
};
