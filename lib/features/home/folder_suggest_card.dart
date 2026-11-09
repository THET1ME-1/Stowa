import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/folder_suggestions.dart';
import '../../l10n/app_localizations.dart';

/// Имя будущей папки: сайт из превью или адрес, вид — словом на языке человека.
String suggestedName(L l, FolderSuggestion suggestion) => switch (suggestion.kind) {
  SuggestKind.screenshot => l.suggestScreenshotsName,
  SuggestKind.video => l.suggestVideosName,
  SuggestKind.file => l.suggestFilesName,
  SuggestKind.voice => l.suggestVoicesName,
  null => suggestion.name ?? suggestion.host!,
};

/// «12 ссылок с habr.com без папки — сделать папку?» Одна карточка за раз.
/// «Сделать» — папка, перенос и правило сайта, с «Отменить»; «Не надо» — навсегда.
class FolderSuggestCard extends ConsumerWidget {
  const FolderSuggestCard({super.key, required this.suggestion});

  final FolderSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final name = suggestedName(l, suggestion);
    final title = switch (suggestion.kind) {
      SuggestKind.screenshot => l.suggestScreenshots(suggestion.count),
      SuggestKind.video => l.suggestVideos(suggestion.count),
      SuggestKind.file => l.suggestFiles(suggestion.count),
      SuggestKind.voice => l.suggestVoices(suggestion.count),
      null => l.suggestSite(suggestion.count, suggestion.host!),
    };

    // ответ запоминается в настройках — в момент нажатия, не при отрисовке
    Future<void> dismiss() => ref.read(dismissSuggestionProvider)(suggestion.key);

    Future<void> make() async {
      final messenger = ScaffoldMessenger.of(context);
      final suggestions = ref.read(folderSuggestionsProvider);
      final done = await suggestions.accept(suggestion, name: name);
      await dismiss();
      showUndo(messenger, message: l.suggestDone(name, suggestion.count), label: l.undo, overDock: true, onUndo: () => suggestions.undo(done));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 16),
      child: Container(
        key: const ValueKey('folder-suggest'),
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(28)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(symbolIcon('create_new_folder'), size: 20, color: Tokens.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.host == null ? l.suggestBody(name) : l.suggestSiteBody(name),
              style: text.bodyMedium!.copyWith(color: Tokens.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 6),
            // на узком экране и крупном шрифте кнопки встают друг под друга, а не вылезают
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 4,
              children: [
                TextButton(onPressed: dismiss, child: Text(l.suggestNo)),
                FilledButton(onPressed: make, child: Text(l.suggestYes)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
