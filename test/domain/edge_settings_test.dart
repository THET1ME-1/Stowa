import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/edge_settings.dart';

void main() {
  const phone = Size(392, 850);

  test('по умолчанию: выключено, справа, на трети высоты, обычные, заметность 86 %', () {
    const settings = EdgeSettings();
    expect(settings.enabled, isFalse);
    expect(settings.side, EdgeSide.right);
    expect(settings.height, 34);
    expect(settings.size, SpineSize.normal);
    expect(settings.alpha, 86);
    expect(settings.hideInFullscreen, isTrue);
  });

  test('подложка: 12, 15, 18 точек шириной и 96, 128, 168 высотой; запас для пальца 18', () {
    expect([for (final size in SpineSize.values) (size.width, size.height)], [(12.0, 96.0), (15.0, 128.0), (18.0, 168.0)]);
    expect(spineTouchExtra, 18);
  });

  test('окно корешков справа прижато к правому краю, слева — к левому, ширина с запасом для пальца', () {
    final right = spineBox(phone, const EdgeSettings());
    expect(right.right, phone.width);
    expect(right.width, 15 + 18);
    expect(right.height, 128);
    final left = spineBox(phone, const EdgeSettings(side: EdgeSide.left));
    expect(left.left, 0);
    expect(left.width, 15 + 18);
  });

  test('по высоте: 0 % — сразу под отступом 80, 100 % — над нижним отступом 80, никогда за экраном', () {
    final top = spineBox(phone, const EdgeSettings(height: 0, size: SpineSize.large));
    expect(top.top, 80);
    final bottom = spineBox(phone, const EdgeSettings(height: 100, size: SpineSize.large));
    expect(bottom.bottom, phone.height - 80);
    // низкий экран (альбомная): корешки помещаются, хоть отступы и не влезают
    final low = spineBox(const Size(850, 300), const EdgeSettings(height: 100, size: SpineSize.large));
    expect(low.top, greaterThanOrEqualTo(0));
    expect(low.bottom, lessThanOrEqualTo(300));
  });

  test('значения за пределами зажимаются: высота 0–100, заметность 40–100', () {
    const settings = EdgeSettings(height: 140, alpha: 10);
    expect(settings.height, 100);
    expect(settings.alpha, 40);
  });

  test('круг в prefs без потерь и равенство по значению', () {
    const settings = EdgeSettings(enabled: true, side: EdgeSide.left, height: 70, size: SpineSize.thin, alpha: 55, hideInFullscreen: false);
    expect(EdgeSettings.fromPrefs(settings.toPrefs()), settings);
    expect(EdgeSettings.fromPrefs(const {}), const EdgeSettings());
    expect(settings.copyWith(height: 20), isNot(settings));
  });
}
