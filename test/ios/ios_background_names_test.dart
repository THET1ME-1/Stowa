import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/services/background.dart';

/// Фоновая задача iPhone с именем, которого нет в Info.plist или в AppDelegate, не запустится
/// никогда и без единой ошибки: имена живут в трёх местах и обязаны совпадать.
void main() {
  test('имена фоновых задач iPhone одни и те же в Dart, Info.plist и AppDelegate', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final permitted = RegExp(r'<key>BGTaskSchedulerPermittedIdentifiers</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist)!.group(1)!;
    final listed = RegExp(r'<string>([^<]+)</string>').allMatches(permitted).map((match) => match.group(1)).toSet();
    expect(listed, iosBackgroundTasks.toSet());

    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    for (final name in iosBackgroundTasks) {
      expect(delegate, contains('"$name"'), reason: 'AppDelegate не регистрирует $name');
    }
  });

  test('Info.plist разрешает фон и спрашивает место «всегда»', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final modes = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist)!.group(1)!;
    expect(modes, allOf(contains('<string>fetch</string>'), contains('<string>processing</string>')));
    expect(plist, contains('<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>'));
  });
}
