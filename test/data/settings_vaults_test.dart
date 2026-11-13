import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stowa/data/settings_repository.dart';

void main() {
  late SettingsRepository settings;
  final now = DateTime(2026, 11, 13, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'vault_path': '/storage/emulated/0/Documents/Stowa', 'vault_mode': 'device', 'vault_asked': true});
    settings = SettingsRepository(await SharedPreferences.getInstance(), MemoryKeyStore(), clock: () => now);
  });

  test('старая установка без vault_db открывает прежнюю базу stowa', () {
    expect(settings.vaultDb, 'stowa');
    expect([for (final one in settings.vaults) one.db], ['stowa']);
  });

  test('новая папка получает свою базу, та же папка — ту же', () async {
    final first = await settings.rememberVault('/storage/emulated/0/Obsidian', VaultMode.device);
    final again = await settings.rememberVault('/storage/emulated/0/Obsidian/', VaultMode.device);
    expect(first.db, startsWith('stowa-'));
    expect(first.db, isNot('stowa'));
    expect(again.db, first.db);
    expect(settings.vaults, hasLength(2));
  });

  test('открыть другое: путь, режим, база и число заметок ушедшего пишутся разом', () async {
    final obsidian = await settings.rememberVault('/storage/emulated/0/Obsidian', VaultMode.device);
    var seen = 0;
    settings.watchVaultPath().listen((_) => seen++);
    await settings.openKnownVault(obsidian, notesHere: 12);
    expect(settings.vaultPath, '/storage/emulated/0/Obsidian');
    expect(settings.vaultMode, VaultMode.device);
    expect(settings.vaultDb, obsidian.db);
    expect(settings.vaultAsked, isTrue);
    final shown = settings.vaults;
    expect(shown.first.db, obsidian.db);
    expect(shown.last.db, 'stowa');
    expect(shown.last.notes, 12);
    expect(shown.last.path, '/storage/emulated/0/Documents/Stowa');
    await Future<void>.delayed(Duration.zero);
    expect(seen, greaterThan(0));
  });

  test('убрать из списка и вернуть', () async {
    final obsidian = await settings.rememberVault('/storage/emulated/0/Obsidian', VaultMode.device);
    await settings.forgetVault(obsidian.db);
    expect([for (final one in settings.vaults) one.db], ['stowa']);
    await settings.restoreVault(obsidian.db);
    expect([for (final one in settings.vaults) one.db], ['stowa', obsidian.db]);
  });
}
