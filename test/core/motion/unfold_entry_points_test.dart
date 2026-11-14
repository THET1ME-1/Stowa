import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/core/motion/stowa_slide.dart';
import 'package:stowa/core/motion/unfold/unfold_route.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/features/folder/folder_screen.dart';
import 'package:stowa/features/item/item_screen.dart';
import 'package:stowa/features/settings/settings_blocks.dart';

/// Экраны растут из нажатой карточки, как в Togetherly. Держится на трёх
/// местах: слушатель касаний в `main`, строитель в теме и маршруты, которые
/// читают тему. Пропадёт одно — все экраны молча вернутся к сдвигу.
void main() {
  test('слушатель касаний ставится при запуске каждого окна', () {
    final main = File('lib/main.dart').readAsStringSync();
    final run = main.substring(main.indexOf('Future<void> _run('));
    expect(run.indexOf('UnfoldTouch.install()'), greaterThan(0));
  });

  test('тема растит экраны на Android и iPhone, запасной — прежний сдвиг', () {
    final builders = buildAppTheme().pageTransitionsTheme.builders;
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final builder = builders[platform];
      expect(builder, isA<UnfoldPageTransitionsBuilder>(), reason: '$platform');
      expect((builder! as UnfoldPageTransitionsBuilder).fallback, isA<StowaSlideTransitionsBuilder>());
    }
  });

  test('заметка, папка и настройки открываются маршрутом темы', () {
    expect(itemRoute('a'), isA<MaterialPageRoute<void>>());
    expect(folderRoute(null), isA<MaterialPageRoute<void>>());
    expect(settingsPageRoute(const SizedBox()), isA<MaterialPageRoute<void>>());
  });

  test('своих сдвигов экранов в lib нет: кроме просмотра фото и полки', () {
    const allowed = {'lib/features/item/photo_viewer.dart', 'lib/features/edge/edge_host.dart'};
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && !allowed.contains(file.path) && file.readAsStringSync().contains('PageRouteBuilder')) file.path,
    ];
    expect(offenders, isEmpty, reason: 'PageRouteBuilder тему не читает и расти из кнопки не будет');
  });
}
