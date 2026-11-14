import 'dart:ui';

/// У какого края экрана стоят корешки.
enum EdgeSide { left, right }

/// Размер корешков: ширина и высота подложки в точках экрана.
enum SpineSize {
  thin(12, 96),
  normal(15, 128),
  large(18, 168);

  const SpineSize(this.width, this.height);

  final double width;
  final double height;
}

/// Невидимый запас для пальца рядом с подложкой: в узкую полоску иначе не попасть.
const spineTouchExtra = 18.0;

/// Отступ корешков от верха и низа экрана: не залезают под строку состояния и полоску жестов.
const _edgeMargin = 80.0;

/// «Под рукой»: где корешки и какие. Живёт в prefs (`edge_*`), Kotlin читает те же ключи
/// как `flutter.edge_*` — имена не менять. Высота и заметность — целые проценты: дробные
/// плагин prefs хранит строкой с приставкой, Kotlin её не прочтёт.
class EdgeSettings {
  const EdgeSettings({
    this.enabled = false,
    this.side = EdgeSide.right,
    int height = 34,
    this.size = SpineSize.normal,
    int alpha = 86,
    this.hideInFullscreen = true,
    this.swipeDownTypes = true,
    this.holdRecords = true,
    this.doubleTapLast = false,
  }) : height = height < 0 ? 0 : (height > 100 ? 100 : height),
       alpha = alpha < 40 ? 40 : (alpha > 100 ? 100 : alpha);

  final bool enabled;
  final EdgeSide side;

  /// Где по высоте, 0–100 %: 0 — у верхнего отступа, 100 — у нижнего.
  final int height;
  final SpineSize size;

  /// Заметность подложки и корешков, 40–100 %.
  final int alpha;

  /// Прятать корешки, пока другое приложение показывает что-то на весь экран (видео).
  final bool hideInFullscreen;

  /// Свайп вниз по корешкам — полка сразу со строкой и клавиатурой.
  final bool swipeDownTypes;

  /// Удержание корешков — запись голоса, отпустил — сохранено.
  final bool holdRecords;

  /// Двойное касание — последняя открытая заметка в полке. Выключено по умолчанию:
  /// чтобы отличить его от одного касания, полка открывалась бы на четверть секунды позже.
  final bool doubleTapLast;

  EdgeSettings copyWith({
    bool? enabled,
    EdgeSide? side,
    int? height,
    SpineSize? size,
    int? alpha,
    bool? hideInFullscreen,
    bool? swipeDownTypes,
    bool? holdRecords,
    bool? doubleTapLast,
  }) => EdgeSettings(
    enabled: enabled ?? this.enabled,
    side: side ?? this.side,
    height: height ?? this.height,
    size: size ?? this.size,
    alpha: alpha ?? this.alpha,
    hideInFullscreen: hideInFullscreen ?? this.hideInFullscreen,
    swipeDownTypes: swipeDownTypes ?? this.swipeDownTypes,
    holdRecords: holdRecords ?? this.holdRecords,
    doubleTapLast: doubleTapLast ?? this.doubleTapLast,
  );

  static const _enabled = 'edge_enabled';
  static const _side = 'edge_side';
  static const _height = 'edge_height';
  static const _size = 'edge_size';
  static const _alpha = 'edge_alpha';
  static const _hideInFullscreen = 'edge_hide_fullscreen';
  static const _swipeDown = 'edge_gesture_swipe';
  static const _hold = 'edge_gesture_hold';
  static const _doubleTap = 'edge_gesture_double';

  /// Ключи prefs; [fromPrefs] читает то же самое.
  static const keys = [_enabled, _side, _height, _size, _alpha, _hideInFullscreen, _swipeDown, _hold, _doubleTap];

  Map<String, Object> toPrefs() => {
    _enabled: enabled,
    _side: side.name,
    _height: height,
    _size: size.name,
    _alpha: alpha,
    _hideInFullscreen: hideInFullscreen,
    _swipeDown: swipeDownTypes,
    _hold: holdRecords,
    _doubleTap: doubleTapLast,
  };

  factory EdgeSettings.fromPrefs(Map<String, Object?> prefs) {
    const fallback = EdgeSettings();
    return EdgeSettings(
      enabled: prefs[_enabled] as bool? ?? fallback.enabled,
      side: EdgeSide.values.asNameMap()[prefs[_side]] ?? fallback.side,
      height: prefs[_height] as int? ?? fallback.height,
      size: SpineSize.values.asNameMap()[prefs[_size]] ?? fallback.size,
      alpha: prefs[_alpha] as int? ?? fallback.alpha,
      hideInFullscreen: prefs[_hideInFullscreen] as bool? ?? fallback.hideInFullscreen,
      swipeDownTypes: prefs[_swipeDown] as bool? ?? fallback.swipeDownTypes,
      holdRecords: prefs[_hold] as bool? ?? fallback.holdRecords,
      doubleTapLast: prefs[_doubleTap] as bool? ?? fallback.doubleTapLast,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EdgeSettings &&
      other.enabled == enabled &&
      other.side == side &&
      other.height == height &&
      other.size == size &&
      other.alpha == alpha &&
      other.hideInFullscreen == hideInFullscreen &&
      other.swipeDownTypes == swipeDownTypes &&
      other.holdRecords == holdRecords &&
      other.doubleTapLast == doubleTapLast;

  @override
  int get hashCode => Object.hash(enabled, side, height, size, alpha, hideInFullscreen, swipeDownTypes, holdRecords, doubleTapLast);
}

/// Окно корешков на экране [screen] (в точках): подложка у своего края и запас для пальца.
/// По высоте — доля между верхним и нижним отступом; на низком экране отступы ужимаются,
/// корешки за экран не уходят.
Rect spineBox(Size screen, EdgeSettings settings) {
  final width = settings.size.width + spineTouchExtra;
  final height = settings.size.height;
  final margin = ((screen.height - height) / 2).clamp(0.0, _edgeMargin);
  final room = (screen.height - margin * 2 - height).clamp(0.0, double.infinity);
  final top = margin + room * settings.height / 100;
  final left = settings.side == EdgeSide.right ? screen.width - width : 0.0;
  return Rect.fromLTWH(left, top, width, height);
}
