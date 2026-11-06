import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/data/providers.dart';

import '../helpers/test_app.dart';

void main() {
  late TestWorld world;
  setUp(() => world = TestWorld());
  tearDown(() => world.dispose());

  test('хранитель файлов один на окно: сервис сохранения пересоздаётся, а он нет', () {
    final container = ProviderContainer(overrides: world.overrides);
    addTearDown(container.dispose);
    final before = container.read(captureServiceProvider);
    // разбор ИИ и место меняются, когда приходят настройки: сервис сохранения строится заново
    container.invalidate(aiDrainProvider);
    container.invalidate(autoSorterProvider);
    final after = container.read(captureServiceProvider);
    expect(identical(before, after), isFalse);
    expect(identical(before.files, after.files), isTrue);
  });

  test('временные файлы (голосовые, входящие бота) — во внутренней памяти, а не в хранилище человека', () {
    final vault = Directory.systemTemp.createTempSync('stowa_vault');
    addTearDown(() => vault.deleteSync(recursive: true));
    final container = ProviderContainer(overrides: [...world.overrides, vaultRootProvider.overrideWith(() => VaultRootNotifier(vault))]);
    addTearDown(container.dispose);
    expect(container.read(filesRootProvider).path, vault.path);
    final scratch = container.read(scratchRootProvider);
    expect(scratch.path, world.files.path);
    expect(p.isWithin(vault.path, scratch.path), isFalse);
  });

  test('ход копирования новый подписчик получает сразу, не дожидаясь следующего процента', () async {
    final container = ProviderContainer(overrides: world.overrides);
    addTearDown(container.dispose);
    final listening = container.listen(fileProgressProvider, (previous, next) {});
    addTearDown(listening.close);
    await container.read(fileProgressProvider.future);
    expect(container.read(fileProgressProvider).value, isEmpty);
  });
}
