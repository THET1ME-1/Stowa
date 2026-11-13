/// Хранилища, которые человек открывал: у каждого своя папка и своя база.
/// Чистые функции над списком из prefs `known_vaults`; запись — `SettingsRepository`.
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

import '../data/settings_repository.dart' show VaultMode;

/// Одно хранилище из списка.
class KnownVault {
  const KnownVault({required this.path, required this.mode, required this.db, this.notes, this.opened, this.hidden = false});

  final String path;
  final VaultMode mode;

  /// Имя файла базы без «.sqlite»: `stowa` у первого хранилища, `stowa-…` у остальных.
  final String db;

  /// Сколько заметок было, когда из хранилища уходили; у открытого считается вживую.
  final int? notes;

  /// Когда открывали последний раз.
  final DateTime? opened;

  /// Убрано из списка: база цела, та же папка снова откроется мгновенно.
  final bool hidden;

  KnownVault copyWith({String? path, VaultMode? mode, int? notes, DateTime? opened, bool? hidden}) =>
      KnownVault(path: path ?? this.path, mode: mode ?? this.mode, db: db, notes: notes ?? this.notes, opened: opened ?? this.opened, hidden: hidden ?? this.hidden);

  Map<String, Object?> toJson() => {
    'path': path,
    'mode': mode.name,
    'db': db,
    'notes': ?notes,
    'opened': ?opened?.toIso8601String(),
    if (hidden) 'hidden': true,
  };

  static KnownVault? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final db = json['db'];
    if (path is! String || db is! String || path.isEmpty || db.isEmpty) return null;
    return KnownVault(
      path: path,
      mode: VaultMode.values.asNameMap()[json['mode']] ?? VaultMode.device,
      db: db,
      notes: json['notes'] is int ? json['notes'] as int : null,
      opened: json['opened'] is String ? DateTime.tryParse(json['opened'] as String) : null,
      hidden: json['hidden'] == true,
    );
  }

  static String encodeList(List<KnownVault> list) => jsonEncode([for (final one in list) one.toJson()]);

  /// Битый текст в prefs — пустой список: открытое хранилище всё равно покажется.
  static List<KnownVault> decodeList(String? text) {
    if (text == null) return const [];
    try {
      final json = jsonDecode(text);
      if (json is! List) return const [];
      return [for (final one in json) ?fromJson(one)];
    } on FormatException {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is KnownVault && other.path == path && other.mode == mode && other.db == db && other.notes == notes && other.opened == opened && other.hidden == hidden;

  @override
  int get hashCode => Object.hash(path, mode, db, notes, opened, hidden);
}

/// Что показывает экран: база открытого и все хранилища списка.
typedef VaultList = ({String current, List<KnownVault> all});

/// Открытое сейчас: путь и режим из `vault_path`/`vault_mode`, база из `vault_db`.
class CurrentVault {
  const CurrentVault({required this.path, required this.mode, required this.db});

  /// null — старая установка, файлы ещё в папке приложения.
  final String? path;
  final VaultMode mode;
  final String db;
}

/// «/a/b/» и «/a/b» — одна папка.
String _same(String path) => p.normalize(path);

/// Две записи пути — одна папка.
bool sameVaultPath(String a, String b) => _same(a) == _same(b);

/// Список для экрана: открытое первым, остальные от недавних к давним, без убранных.
List<KnownVault> knownVaults(List<KnownVault> stored, {required CurrentVault current}) {
  final own = stored.where((one) => one.db == current.db).firstOrNull;
  final others = [
    for (final one in stored)
      if (one.db != current.db && !one.hidden) one,
  ]..sort((a, b) => (b.opened ?? DateTime(0)).compareTo(a.opened ?? DateTime(0)));
  return [
    if (current.path case final path?) (own ?? KnownVault(path: path, mode: current.mode, db: current.db)).copyWith(path: path, mode: current.mode, hidden: false),
    ...others,
  ];
}

/// Запись для папки: знакомая (и убранная) — она же, иначе новая с базой [newDb].
(List<KnownVault>, KnownVault) rememberVault(List<KnownVault> stored, {required String path, required VaultMode mode, required String newDb}) {
  final index = stored.indexWhere((one) => _same(one.path) == _same(path));
  if (index >= 0) {
    final entry = stored[index].copyWith(hidden: false);
    return ([...stored]..[index] = entry, entry);
  }
  final entry = KnownVault(path: _same(path), mode: mode, db: newDb);
  return ([...stored, entry], entry);
}

/// Уходя из открытого, запомнить его путь, число заметок и время.
List<KnownVault> leaveVault(List<KnownVault> stored, {required CurrentVault current, required int notes, required DateTime now}) {
  final path = current.path;
  if (path == null) return stored;
  final rest = [for (final one in stored) if (one.db != current.db) one];
  return [...rest, KnownVault(path: path, mode: current.mode, db: current.db, notes: notes, opened: now)];
}

/// Открыли хранилище [db]: время открытия.
List<KnownVault> touchVault(List<KnownVault> stored, {required String db, required DateTime now}) => [
  for (final one in stored) one.db == db ? one.copyWith(opened: now, hidden: false) : one,
];

/// Убрать из списка: запись скрывается, база и папка остаются.
List<KnownVault> forgetVault(List<KnownVault> stored, {required String db}) => [
  for (final one in stored) one.db == db ? one.copyWith(hidden: true) : one,
];

/// Имя хранилища для глаз — имя его папки.
String vaultTitle(String path) => p.basename(_same(path));

/// Где лежит папка, коротко: «Documents» для «/storage/emulated/0/Documents/Stowa»; в корне
/// памяти — пусто; глубже двух папок — «…/Notes/Work».
String vaultParent(String path) {
  final parent = p.dirname(_same(path)).replaceFirst(RegExp(r'^/storage/emulated/0/?'), '');
  if (parent == '.' || parent == '/' || parent.isEmpty) return '';
  final parts = parent.split('/').where((part) => part.isNotEmpty).toList();
  return parts.length > 2 ? '…/${parts.sublist(parts.length - 2).join('/')}' : parts.join('/');
}
