import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../domain/backup_nudge.dart';
import '../../l10n/app_localizations.dart';
import '../settings/storage_screen.dart' show saveBackup;

/// Плашки на главной для того, у кого заметки лежат только в браузере: «сохраните копию»
/// и «браузер не дал надёжного хранилища». Браузер вправе стереть данные сайта, и терять
/// заметки молча нельзя. Нечего сказать — плашки нет и места она не занимает.
class CopyNudge extends StatelessWidget {
  const CopyNudge({super.key, required this.nudge, required this.storageWeak, required this.onSave, required this.onLater, this.padding = EdgeInsets.zero});

  final BackupNudge nudge;

  /// База в браузере работает в памяти или в ненадёжном режиме.
  final bool storageWeak;
  final VoidCallback onSave;

  /// «Позже»: не напоминать неделю.
  final VoidCallback onLater;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (nudge == BackupNudge.none && !storageWeak) return const SizedBox.shrink();
    final l = L.of(context);
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (storageWeak) _Card(icon: 'warning', text: l.storageWeak),
          if (storageWeak && nudge != BackupNudge.none) const SizedBox(height: 8),
          if (nudge != BackupNudge.none)
            _Card(
              key: const ValueKey('copy-nudge'),
              icon: 'backup',
              text: nudge == BackupNudge.first ? l.copyNudgeFirst : l.copyNudgeStale,
              actions: [
                FilledButton(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 16)),
                  onPressed: onSave,
                  child: Text(l.backupSave),
                ),
                TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: Tokens.onSurfaceVariant),
                  onPressed: onLater,
                  child: Text(l.copyNudgeLater),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.icon, required this.text, this.actions = const []});

  final String icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(symbolIcon(icon, filled: true), size: 18, color: Tokens.accent)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 14, height: 1.35, color: Tokens.onSurface)),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(22)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.isEmpty) return line;
          // в широкой плашке кнопки стоят справа от текста, в узкой — под ним
          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(child: line),
                const SizedBox(width: 12),
                ...actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              line,
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.only(left: 28), child: Wrap(spacing: 4, runSpacing: 4, children: actions)),
            ],
          );
        },
      ),
    );
  }
}

/// [CopyNudge], подключённая к хранилищу: что сказать, решает [copyNudgeProvider].
class CopyNudgeHost extends ConsumerWidget {
  const CopyNudgeHost({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CopyNudge(
      nudge: ref.watch(copyNudgeProvider).value ?? BackupNudge.none,
      storageWeak: ref.watch(storageWeakProvider).value ?? false,
      padding: padding,
      onSave: () => saveBackup(context, ref),
      onLater: () => ref.read(settingsRepositoryProvider).snoozeCopy(ref.read(clockProvider)().add(backupStaleAfter)),
    );
  }
}
