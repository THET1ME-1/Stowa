import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/privacy/markdown_export.dart';
import '../vault/vault_actions.dart';

/// «Выгрузить в Markdown»: выбрать папку, при открытом скрытом спросить про него, выгрузить.
Future<void> exportMarkdownFlow(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final vault = ref.read(vaultRootProvider);
  if (vault == null) {
    showNote(messenger, l.markdownNoVault);
    return;
  }
  final picked = await ref.read(vaultPickerProvider)();
  if (picked == null || !context.mounted) return;
  if (!await ensureFileAccess(context, ref) || !context.mounted) return;
  var includeHidden = false;
  if (ref.read(privacyServiceProvider).isOpen) {
    final answer = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen + 8, 0, Space.screen + 8, Space.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.markdownHiddenAsk, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(l.markdownHiddenHint, style: Theme.of(sheet).textTheme.bodyMedium!.copyWith(color: Tokens.muted, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(sheet, false),
                child: Text(l.markdownWithoutHidden),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(sheet, true),
                child: Text(l.markdownWithHidden),
              ),
            ],
          ),
        ),
      ),
    );
    if (answer == null) return;
    includeHidden = answer;
  }
  try {
    // сперва дописать в файлы всё, что ещё в очереди
    await ref.read(vaultWriterProvider).drain();
    final done = await MarkdownExport(
      ref.read(databaseProvider),
      vault: vault,
      clock: ref.read(clockProvider),
    ).export(Directory(picked), includeHidden: includeHidden);
    showNote(messenger, l.markdownDone(done.path));
  } on FileSystemException {
    showNote(messenger, l.markdownFailed);
  }
}
