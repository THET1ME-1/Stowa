import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/undo_snack.dart';
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/privacy/privacy_service.dart';
import '../../services/privacy/seal_crypto.dart';
import 'code_entry.dart';

/// Отпечаток пальца за тонкой стенкой: в тестах подменяется.
abstract interface class Biometrics {
  /// На телефоне есть датчик и заведён палец.
  Future<bool> available();

  /// Спросить палец; отказ, ошибка или нет датчика — false.
  Future<bool> confirm(String reason);
}

class DeviceBiometrics implements Biometrics {
  const DeviceBiometrics();

  @override
  Future<bool> available() async {
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics && (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> confirm(String reason) async {
    try {
      return await LocalAuthentication().authenticate(localizedReason: reason, biometricOnly: true);
    } catch (_) {
      return false;
    }
  }
}

final biometricsProvider = Provider<Biometrics>((ref) => const DeviceBiometrics());

/// Сколько стоит ключ из кода: в тестах — дёшево.
final kdfSettingsProvider = Provider<KdfSettings>((ref) => const KdfSettings());

/// Отпечаток включён: есть датчик и ключ для него на этом телефоне.
final fingerprintOnProvider = StreamProvider<bool>((ref) async* {
  final privacy = ref.watch(privacyServiceProvider);
  yield await privacy.hasFingerprintKey();
  yield* privacy.changes.asyncMap((_) => privacy.hasFingerprintKey());
});

/// Идёт свой запрос отпечатка: окно датчика уводит приложение в фон, замок от этого не закрывается.
final privacyBusyProvider = NotifierProvider<PrivacyBusy, bool>(PrivacyBusy.new);

class PrivacyBusy extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool busy) => state = busy;
}

Future<bool> _withBusy(WidgetRef ref, Future<bool> Function() work) async {
  ref.read(privacyBusyProvider.notifier).set(true);
  try {
    return await work();
  } finally {
    ref.read(privacyBusyProvider.notifier).set(false);
  }
}

Future<bool> askFingerprint(WidgetRef ref, String reason) => _withBusy(ref, () => ref.read(biometricsProvider).confirm(reason));

/// Экран кода поверх всего; плашка снизу закрыла бы кнопку «Готово» — она уходит.
Future<T?> _pushCode<T>(BuildContext context, Widget child) {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  return Navigator.of(context).push<T>(_codeRoute(child));
}

Route<T> _codeRoute<T>(Widget child) => MaterialPageRoute<T>(
  fullscreenDialog: true,
  builder: (context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(icon: Icon(symbolIcon('close')), tooltip: L.of(context).cancel, onPressed: () => Navigator.pop(context)),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: child),
      ),
    ),
  ),
);

/// Ошибка неверного кода с учётом ожидания после череды ошибок.
Future<String> _wrongCode(L l, PrivacyService privacy) async {
  final until = await privacy.waitUntil();
  return until == null ? l.codeWrong : l.codeWait(until.difference(DateTime.now()).inSeconds + 1);
}

/// Завести код: придумать и повторить. Скрытое после этого открыто и пустое.
Future<bool> createCodeFlow(BuildContext context, WidgetRef ref) async {
  final created = await _pushCode<bool>(context, const _NewCode());
  return created ?? false;
}

class _NewCode extends ConsumerStatefulWidget {
  const _NewCode();

  @override
  ConsumerState<_NewCode> createState() => _NewCodeState();
}

class _NewCodeState extends ConsumerState<_NewCode> {
  final _entry = GlobalKey<CodeEntryState>();
  String? _first;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return CodeEntry(
      key: _entry,
      title: _first == null ? l.codeCreateTitle : l.codeRepeatTitle,
      subtitle: _first == null ? l.codeCreateHint : null,
      onSubmit: (code) async {
        if (_first == null) {
          setState(() => _first = code);
          _entry.currentState?.reset();
          return null;
        }
        if (code != _first) {
          setState(() => _first = null);
          return l.codeMismatch;
        }
        final privacy = ref.read(privacyServiceProvider);
        final keys = await privacy.createCode(code, kdf: ref.read(kdfSettingsProvider));
        // отпечаток включается сам, если он есть: его можно выключить в настройках
        if (await ref.read(biometricsProvider).available()) await privacy.rememberForFingerprint(keys);
        if (context.mounted) Navigator.pop(context, true);
        return null;
      },
    );
  }
}

/// Открыть скрытое: отпечатком, если он включён, иначе кодом. Кода нет — завести.
Future<bool> openHiddenFlow(BuildContext context, WidgetRef ref) async {
  final privacy = ref.read(privacyServiceProvider);
  if (privacy.isOpen) return true;
  await privacy.loadLock();
  if (!context.mounted) return false;
  if (!privacy.hasCode) return createCodeFlow(context, ref);
  final l = L.of(context);
  if (await privacy.hasFingerprintKey() && await askFingerprint(ref, l.hiddenOpenReason) && await privacy.openWithFingerprint()) return true;
  if (!context.mounted) return false;
  final opened = await _pushCode<bool>(
    context,
    Builder(
      builder: (page) => CodeEntry(
        title: l.hiddenOpenTitle,
        onFingerprint: null,
        onSubmit: (code) async {
          if (!await privacy.openWithCode(code)) return _wrongCode(l, privacy);
          // отпечаток есть, а ключа для него ещё нет (после переустановки): запомнить
          if (!await privacy.hasFingerprintKey() && await ref.read(biometricsProvider).available()) await privacy.rememberForFingerprint();
          if (page.mounted) Navigator.pop(page, true);
          return null;
        },
        footer: TextButton(onPressed: () => forgetCodeFlow(page, ref), child: Text(l.codeForgot)),
      ),
    ),
  );
  return opened ?? false;
}

/// Проверить код и отдать ключи: включить отпечаток, когда скрытое закрыто.
Future<SealKeys?> askCodeFlow(BuildContext context, WidgetRef ref, {required String title}) {
  final l = L.of(context);
  final privacy = ref.read(privacyServiceProvider);
  return _pushCode<SealKeys>(
    context,
    Builder(
      builder: (page) => CodeEntry(
        title: title,
        onSubmit: (code) async {
          final keys = await privacy.checkCode(code);
          if (keys == null) return _wrongCode(l, privacy);
          if (page.mounted) Navigator.pop(page, keys);
          return null;
        },
      ),
    ),
  );
}

/// Сменить код: старый, новый, повтор.
Future<bool> changeCodeFlow(BuildContext context, WidgetRef ref) async => await _pushCode<bool>(context, const _ChangeCode()) ?? false;

class _ChangeCode extends ConsumerStatefulWidget {
  const _ChangeCode();

  @override
  ConsumerState<_ChangeCode> createState() => _ChangeCodeState();
}

class _ChangeCodeState extends ConsumerState<_ChangeCode> {
  final _entry = GlobalKey<CodeEntryState>();
  String? _old;
  String? _first;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final privacy = ref.read(privacyServiceProvider);
    return CodeEntry(
      key: _entry,
      title: _old == null ? l.codeOldTitle : (_first == null ? l.codeNewTitle : l.codeRepeatTitle),
      onSubmit: (code) async {
        if (_old == null) {
          if (await privacy.checkCode(code) == null) return _wrongCode(l, privacy);
          setState(() => _old = code);
          _entry.currentState?.reset();
          return null;
        }
        if (_first == null) {
          setState(() => _first = code);
          _entry.currentState?.reset();
          return null;
        }
        if (code != _first) {
          setState(() => _first = null);
          return l.codeMismatch;
        }
        await privacy.changeCode(_old!, code, kdf: ref.read(kdfSettingsProvider));
        if (context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          showNote(messenger, l.codeChanged);
        }
        return null;
      },
    );
  }
}

/// «Забыл код»: снять замок и стереть скрытое насовсем, после предупреждения.
Future<bool> forgetCodeFlow(BuildContext context, WidgetRef ref) async {
  final l = L.of(context);
  final text = Theme.of(context).textTheme;
  final sure = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen + 8, 0, Space.screen + 8, Space.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.codeForgetTitle, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(l.codeForgetText, style: text.bodyMedium!.copyWith(color: Tokens.muted, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tokens.error, foregroundColor: Tokens.onError, minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(l.codeForgetAction),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(sheet, false), child: Text(l.cancel)),
          ],
        ),
      ),
    ),
  );
  if (sure != true) return false;
  await ref.read(privacyServiceProvider).forget();
  if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  return true;
}

/// Скрыть папку: скрытое открывается (или заводится код), папка уходит в него.
Future<void> hideFolderFlow(BuildContext context, WidgetRef ref, FolderCard folder) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = L.of(context);
  if (!await openHiddenFlow(context, ref)) return;
  final privacy = ref.read(privacyServiceProvider);
  await privacy.hideFolder(folder.id);
  showUndo(
    messenger,
    message: l.folderHidden(folder.name),
    label: l.restoreAction,
    onUndo: () => privacy.unhideFolder(folder.id).ignore(),
    duration: const Duration(seconds: 8),
  );
}

Future<void> unhideFolderFlow(BuildContext context, WidgetRef ref, FolderCard folder) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = L.of(context);
  await ref.read(privacyServiceProvider).unhideFolder(folder.id);
  showNote(messenger, l.folderUnhidden(folder.name));
}

/// Закрыть скрытое сейчас.
Future<void> closeHidden(WidgetRef ref) => ref.read(privacyServiceProvider).close();
