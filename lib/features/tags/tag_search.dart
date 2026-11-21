import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workspace/workspace_model.dart' show WsTab;
import '../workspace/workspace_shell.dart' show WorkspaceScope;

/// Просьба показать заметки с тегом. [serial] растёт на каждую: тот же тег второй раз
/// подряд — тоже новая просьба.
class TagSearchRequest {
  const TagSearchRequest(this.tag, this.serial);

  final String tag;
  final int serial;
}

/// Главная слушает и ставит своей строке поиск по тегу: строка у неё одна и на телефоне,
/// и на мониторе.
final tagSearchProvider = NotifierProvider<TagSearch, TagSearchRequest?>(TagSearch.new);

class TagSearch extends Notifier<TagSearchRequest?> {
  @override
  TagSearchRequest? build() => null;

  void show(String tag) => state = TagSearchRequest(tag, (state?.serial ?? 0) + 1);
}

/// Касание тега (STOWA-10): главная с поиском по нему. На мониторе открывается вкладка
/// «Главная», а заметка остаётся своей вкладкой; на телефоне экраны поверх главной
/// закрываются. [context] — экрана, а не окна поверх него: окно на мониторе живёт над
/// оболочкой и вкладок не видит.
void showTagNotes(BuildContext context, String tag) {
  final requests = ProviderScope.containerOf(context, listen: false).read(tagSearchProvider.notifier);
  final workspace = WorkspaceScope.maybeOf(context);
  if (workspace != null) {
    workspace.open(const WsTab.home());
  } else {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
  requests.show(tag);
}
