import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/db/database.dart';
import '../../data/settings_repository.dart';

/// В базе уже есть вещи (в том числе в корзине): установка не новая, хранилище само не заводится.
Future<bool> hasSavedItems(AppDatabase db) async => await db.items.count().getSingle() > 0;

/// Разрешение «Доступ ко всем файлам» (до Android 11 — запись в память устройства).
/// Канал `stowa/vault` есть у главного окна и у «Поделиться».
class VaultChannel {
  const VaultChannel();

  static const _channel = MethodChannel('stowa/vault');

  /// Нет канала (фоновая задача) — считаем, что доступ есть: отозвали — запись упадёт и подождёт.
  Future<bool> hasAllFiles() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFiles') ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Открыть системный экран разрешения; ответ — при возврате в приложение.
  Future<void> askAllFiles() => _channel.invokeMethod<void>('askAllFiles');
}

/// Где на этом запуске лежат файлы и доступно ли хранилище.
class VaultPlace {
  const VaultPlace({required this.files, required this.vault, required this.reachable});

  /// Корень, от которого считаются пути в базе.
  final Directory files;

  /// Хранилище файлами; null — не выбрано (старая установка) или недоступно.
  final Directory? vault;

  /// false — папки нет или отозвали разрешение: показать «Хранилище не найдено».
  final bool reachable;
}

class VaultLocation {
  VaultLocation({required this.settings, required this.appSupport, this.channel = const VaultChannel()});

  final SettingsRepository settings;
  final Directory appSupport;
  final VaultChannel channel;

  /// Хранилище внутри приложения: без разрешений, удаляется вместе с приложением.
  Directory get appVault => Directory(p.join(appSupport.path, 'vault'));

  /// Подсказка в окне выбора папки — только подсказка: выбирает человек.
  static const suggestedFolder = '/storage/emulated/0/Documents';

  /// Корень этого запуска. Новая установка без данных сразу получает хранилище внутри
  /// приложения, чтобы «Поделиться» и фон работали до выбора; старая остаётся на прежнем
  /// месте, пока человек не перенесёт её на экране первого запуска.
  Future<VaultPlace> resolve({required bool hasData}) async {
    var path = settings.vaultPath;
    if (path == null && !hasData) {
      await appVault.create(recursive: true);
      await settings.setVault(appVault.path, VaultMode.app, asked: false);
      path = appVault.path;
    }
    if (path == null) return VaultPlace(files: appSupport, vault: null, reachable: true);
    final root = Directory(path);
    final reachable = await hasAccess(root, settings.vaultMode);
    return VaultPlace(files: root, vault: reachable ? root : null, reachable: reachable);
  }

  /// Папка на месте и, для памяти устройства, разрешение дано.
  Future<bool> hasAccess(Directory root, VaultMode mode) async {
    if (mode == VaultMode.device && !await channel.hasAllFiles()) return false;
    return root.exists();
  }

}

/// Выбор папки системным окном, с подсказкой «Документы».
Future<String?> pickVaultFolder() => FilePicker.getDirectoryPath(initialDirectory: VaultLocation.suggestedFolder);
