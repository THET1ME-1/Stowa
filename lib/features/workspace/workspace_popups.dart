import 'package:flutter/widgets.dart';

/// Окна поверх вкладок рабочего пространства: нижние листы, диалоги, меню.
///
/// Общая строка ввода лежит поверх всех вкладок, а окна открываются внутри своей
/// вкладки, то есть под строкой: кнопки нижнего листа оказывались за ней. Пока во
/// вкладке открыто такое окно, строка уступает ему место.
class WorkspacePopups {
  final _open = <Route<dynamic>>{};

  /// Сейчас поверх какой-нибудь вкладки есть окно.
  final covering = ValueNotifier<bool>(false);

  /// Наблюдатель для навигатора одной вкладки: у каждого навигатора свой.
  NavigatorObserver watch() => _PopupWatch(this);

  void _opened(Route<dynamic> route) {
    if (route is! PopupRoute) return;
    _open.add(route);
    settle();
  }

  void _closed(Route<dynamic> route) {
    if (_open.remove(route)) settle();
  }

  /// Сверить со живыми окнами: вкладку могли закрыть вместе с открытым листом, и о его
  /// конце навигатор уже не скажет.
  void settle() {
    _open.removeWhere((route) => !route.isActive);
    covering.value = _open.isNotEmpty;
  }
}

class _PopupWatch extends NavigatorObserver {
  _PopupWatch(this._popups);

  final WorkspacePopups _popups;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _popups._opened(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _popups._closed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _popups._closed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _popups._closed(oldRoute);
    if (newRoute != null) _popups._opened(newRoute);
  }
}
