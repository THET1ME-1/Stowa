import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/settings_repository.dart' show VaultMode;
import 'package:stowa/domain/known_vaults.dart';

void main() {
  final monday = DateTime(2026, 11, 9, 10);
  final tuesday = DateTime(2026, 11, 10, 10);

  KnownVault vault(String path, String db, {DateTime? opened, int? notes, bool hidden = false}) =>
      KnownVault(path: path, mode: VaultMode.device, db: db, opened: opened, notes: notes, hidden: hidden);

  group('список для экрана', () {
    test('старая установка без списка: открытое одно, с базой stowa', () {
      final shown = knownVaults(const [], current: const CurrentVault(path: '/storage/emulated/0/Documents/Stowa', mode: VaultMode.device, db: 'stowa'));
      expect(shown, hasLength(1));
      expect(shown.single.db, 'stowa');
      expect(shown.single.path, '/storage/emulated/0/Documents/Stowa');
    });

    test('открытое первым, остальные от нового к старому, скрытых нет', () {
      final stored = [
        vault('/a', 'stowa-a', opened: monday),
        vault('/b', 'stowa-b', opened: tuesday),
        vault('/c', 'stowa-c', opened: tuesday, hidden: true),
        vault('/old', 'stowa', opened: monday),
      ];
      final shown = knownVaults(stored, current: const CurrentVault(path: '/now', mode: VaultMode.device, db: 'stowa'));
      expect([for (final one in shown) one.db], ['stowa', 'stowa-b', 'stowa-a']);
    });

    test('путь и режим открытого — из настроек: его перенесли', () {
      final shown = knownVaults([vault('/old', 'stowa')], current: const CurrentVault(path: '/moved', mode: VaultMode.app, db: 'stowa'));
      expect(shown.single.path, '/moved');
      expect(shown.single.mode, VaultMode.app);
    });

    test('у открытого нет пути (старая установка до переноса) — его в списке нет', () {
      final shown = knownVaults([vault('/a', 'stowa-a')], current: const CurrentVault(path: null, mode: VaultMode.app, db: 'stowa'));
      expect([for (final one in shown) one.db], ['stowa-a']);
    });
  });

  group('запомнить папку', () {
    test('новая папка — новая запись с новой базой', () {
      final (list, entry) = rememberVault(const [], path: '/x', mode: VaultMode.device, newDb: 'stowa-1');
      expect(entry.db, 'stowa-1');
      expect(list.single.path, '/x');
    });

    test('та же папка с хвостом «/» — та же запись, скрытая раскрывается', () {
      final (list, entry) = rememberVault([vault('/x', 'stowa-old', hidden: true)], path: '/x/', mode: VaultMode.device, newDb: 'stowa-new');
      expect(entry.db, 'stowa-old');
      expect(entry.hidden, isFalse);
      expect(list, hasLength(1));
    });
  });

  test('уходя, открытое запоминает число заметок и время', () {
    final list = leaveVault(const [], current: const CurrentVault(path: '/a', mode: VaultMode.device, db: 'stowa'), notes: 42, now: tuesday);
    expect(list.single.notes, 42);
    expect(list.single.opened, tuesday);
    expect(list.single.path, '/a');
  });

  test('открыть: время цели обновляется', () {
    final list = touchVault([vault('/a', 'stowa-a', opened: monday)], db: 'stowa-a', now: tuesday);
    expect(list.single.opened, tuesday);
  });

  test('убрать из списка — скрыть, а не стереть', () {
    final list = forgetVault([vault('/a', 'stowa-a')], db: 'stowa-a');
    expect(list.single.hidden, isTrue);
  });

  test('json туда и обратно', () {
    final one = vault('/a', 'stowa-a', opened: monday, notes: 3);
    expect(KnownVault.decodeList(KnownVault.encodeList([one])).single, one);
    expect(KnownVault.decodeList('не json'), isEmpty);
    expect(KnownVault.decodeList(null), isEmpty);
  });

  test('имя для глаз: последняя часть пути', () {
    expect(vaultTitle('/storage/emulated/0/Documents/Obsidian'), 'Obsidian');
    expect(vaultParent('/storage/emulated/0/Documents/Obsidian'), 'Documents');
    expect(vaultParent('/storage/emulated/0/Stowa'), '');
    expect(vaultParent('/storage/emulated/0/Documents/Notes/Work/Stowa'), '…/Notes/Work');
    expect(vaultParent('/storage/1A2B-3C4D/Stowa'), 'storage/1A2B-3C4D');
  });
}
