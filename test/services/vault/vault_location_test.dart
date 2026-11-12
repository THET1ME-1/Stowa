import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/settings_repository.dart';
import 'package:stowa/services/vault/vault_location.dart';

class _FakeChannel implements VaultChannel {
  _FakeChannel(this.granted);

  bool granted;
  var asked = 0;

  @override
  Future<bool> hasAllFiles() async => granted;

  @override
  Future<void> askAllFiles() async => asked++;
}

void main() {
  late SettingsRepository settings;
  late Directory appSupport;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    appSupport = Directory.systemTemp.createTempSync('stowa_app');
  });
  tearDown(() => appSupport.deleteSync(recursive: true));

  VaultLocation location({bool granted = true}) => VaultLocation(settings: settings, appSupport: appSupport, channel: _FakeChannel(granted));

  test('новая установка без данных — хранилище внутри приложения, выбор ещё не спрашивали', () async {
    final place = await location().resolve(hasData: false);
    expect(place.vault!.path, p.join(appSupport.path, 'vault'));
    expect(place.files.path, place.vault!.path);
    expect(Directory(place.vault!.path).existsSync(), isTrue);
    expect(settings.vaultMode, VaultMode.app);
    expect(settings.vaultAsked, isFalse);
  });

  test('старая установка с данными — файлы на старом месте, хранилища нет до переноса', () async {
    final place = await location().resolve(hasData: true);
    expect(place.vault, isNull);
    expect(place.files.path, appSupport.path);
    expect(settings.vaultPath, isNull);
  });

  test('выбранная папка сохраняется и читается после перезапуска', () async {
    final chosen = Directory(p.join(appSupport.path, 'Documents', 'Stowa'))..createSync(recursive: true);
    await settings.setVault(chosen.path, VaultMode.device);
    final again = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore());
    expect(again.vaultPath, chosen.path);
    expect(again.vaultMode, VaultMode.device);
    expect(again.vaultAsked, isTrue);
    final place = await VaultLocation(settings: again, appSupport: appSupport, channel: _FakeChannel(true)).resolve(hasData: true);
    expect(place.vault!.path, chosen.path);
    expect(place.reachable, isTrue);
  });

  test('память устройства без разрешения или без папки — хранилище недоступно', () async {
    final chosen = Directory(p.join(appSupport.path, 'Documents', 'Stowa'))..createSync(recursive: true);
    await settings.setVault(chosen.path, VaultMode.device);
    final denied = await location(granted: false).resolve(hasData: true);
    expect(denied.reachable, isFalse);
    expect(denied.vault, isNull);
    chosen.deleteSync();
    final gone = await location().resolve(hasData: true);
    expect(gone.reachable, isFalse);
  });

  test('iPhone: хранилище — папка «Документы» приложения, выбирать нечего', () async {
    final documents = Directory(p.join(appSupport.path, 'Documents'));
    final place = await VaultLocation(settings: settings, appSupport: appSupport, home: documents).resolve(hasData: false);
    expect(place.vault!.path, documents.path);
    expect(place.files.path, documents.path);
    expect(documents.existsSync(), isTrue);
    expect(place.reachable, isTrue);
    expect(settings.vaultAsked, isTrue);
  });

  test('iPhone: после обновления папка приложения переехала — старый путь не в счёт', () async {
    await settings.setVault('/var/mobile/Containers/Data/Application/OLD/Documents', VaultMode.app);
    final documents = Directory(p.join(appSupport.path, 'Documents'));
    final place = await VaultLocation(settings: settings, appSupport: appSupport, home: documents).resolve(hasData: true);
    expect(place.vault!.path, documents.path);
    expect(place.reachable, isTrue);
    expect(settings.vaultPath, documents.path);
  });

  test('хранилище внутри приложения разрешения не спрашивает', () async {
    final channel = _FakeChannel(false);
    final inside = VaultLocation(settings: settings, appSupport: appSupport, channel: channel);
    final place = await inside.resolve(hasData: false);
    expect(place.reachable, isTrue);
    expect(channel.asked, 0);
  });
}
