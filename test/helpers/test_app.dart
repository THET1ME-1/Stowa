import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:stowa/app.dart';
import 'package:stowa/core/theme/app_theme.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/providers.dart';
import 'package:stowa/l10n/app_localizations.dart';

/// База в памяти, своя папка файлов и замёрзшие часы — для виджет-тестов.
class TestWorld {
  TestWorld({DateTime? now}) : now = now ?? DateTime(2026, 11, 2, 10);

  final DateTime now;
  final db = AppDatabase.memory();
  final files = Directory.systemTemp.createTempSync('stowa_test');

  List<Override> get overrides => [
        databaseProvider.overrideWithValue(db),
        filesRootProvider.overrideWithValue(files),
        clockProvider.overrideWithValue(() => now),
        // превью ссылок в тестах без интернета: сеть «молчит», вещь остаётся как есть
        linkFetchProvider.overrideWithValue((uri) async => throw const SocketException('тест без сети')),
      ];

  Widget app({Locale locale = const Locale('ru')}) => ProviderScope(overrides: overrides, child: StowaApp(locale: locale));

  /// Один виджет на теме и словарях приложения.
  Widget wrap(Widget child, {Locale locale = const Locale('ru')}) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: buildAppTheme(),
          locale: locale,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  Future<void> dispose() async {
    await db.close();
    if (files.existsSync()) files.deleteSync(recursive: true);
  }
}
