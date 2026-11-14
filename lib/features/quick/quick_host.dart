import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';
import '../../services/capture_service.dart';
import '../../services/launch_actions.dart';
import '../../services/privacy/hidden_rows.dart';
import '../composer/line_dock.dart';
import '../composer/picked_files.dart';

/// Сколько окно ждёт файлы заметки, прежде чем отдать их фону.
const _fileWait = Duration(seconds: 3);

/// Сколько висит плашка об отказе, прежде чем окно закроется.
const _noticeWait = Duration(milliseconds: 2500);

/// Окно виджета: одна строка поверх рабочего стола, главная Stowa не открывается.
/// Закинул, плашка ушла — окно закрылось, человек снова на рабочем столе.
class QuickHost extends ConsumerStatefulWidget {
  const QuickHost({
    super.key,
    this.action = quickAction,
    this.carried = carriedText,
    this.takePhoto = pickCameraPhoto,
    this.openNote = openNoteInApp,
    this.onFinish = SystemNavigator.pop,
  });

  /// Какую кнопку виджета нажали. В тестах подменяется.
  final Future<LaunchAction> Function() action;

  /// Что набрали в полке «Под рукой», прежде чем она передала дело сюда.
  final Future<String?> Function() carried;

  /// Камера телефона.
  final Future<List<PickedFile>> Function() takePhoto;

  /// Открыть заметку в самом приложении.
  final Future<void> Function(String id) openNote;

  /// Закрыть окно.
  final Future<void> Function() onFinish;

  @override
  ConsumerState<QuickHost> createState() => _QuickHostState();
}

class _QuickHostState extends ConsumerState<QuickHost> with WidgetsBindingObserver {
  static const _window = MethodChannel('stowa/window');

  final _dock = GlobalKey<LineDockState>();
  bool _started = false;
  bool _finishing = false;

  /// Окно само открыло другое ради результата (камера, выбор файла): это не уход.
  bool _ownWindow = false;

  // пока база не ответила, считаем скрытое открытым: поиск не покажет лишнего
  bool _hiddenOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _window.setMethodCallHandler((call) async {
      if (call.method == 'ownWindow') _ownWindow = true;
    });
    // напоминание из набранного встаёт сразу, не дожидаясь главного окна
    ref.listenManual(remindersProvider, (previous, next) {
      final reminders = next.value;
      if (reminders != null) ref.read(reminderServiceProvider).sync(reminders, ref.read(clockProvider)());
    });
    // открытое скрытое лежит в базе обычными строками, а ключи от него — в главном окне
    hiddenFolderIds(ref.read(databaseProvider)).then((folders) {
      if (mounted) setState(() => _hiddenOpen = folders.isNotEmpty);
    }).ignore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // окно ещё за рабочим столом: клавиатура не встанет, действие ждёт выхода вперёд
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) _start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _window.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _ownWindow = false;
        _start();
      case AppLifecycleState.paused:
        // ушли на рабочий стол или в другое приложение: невидимое окно с записью голоса не держим
        if (_started && !_ownWindow) _finish();
      case AppLifecycleState.inactive || AppLifecycleState.hidden || AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    _started = true;
    final action = await widget.action();
    final carried = await widget.carried();
    final dock = _dock.currentState;
    if (!mounted || _finishing || dock == null) return;
    if (carried != null && carried.isNotEmpty) dock.prefill(carried);
    switch (action) {
      case LaunchAction.compose:
        _compose(dock);
      case LaunchAction.attach:
        dock.openTray();
      case LaunchAction.voice:
        if (await dock.startVoice()) return;
        // строка уже сказала «Нет доступа к микрофону»: даём прочитать
        await Future<void>.delayed(_noticeWait);
        await _finish();
      case LaunchAction.camera:
        var photos = const <PickedFile>[];
        try {
          photos = await widget.takePhoto();
        } on PlatformException {
          // камеры нет или её не дали: снимка нет
        }
        if (!mounted) return;
        if (photos.isEmpty) return _finish();
        dock.attach(photos);
        _compose(dock);
    }
  }

  void _compose(LineDockState dock) {
    dock.focusLine();
    // окно получает фокус позже первого кадра, и первый запрос клавиатуры
    // Android молча пропускает: просим ещё раз
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted && !_finishing) SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }).ignore();
  }

  Future<void> _open(String id) async {
    await widget.openNote(id);
    await _finish();
  }

  /// Касание мимо строки закрывает окно. Набранное сперва прикрывает затемнение самой строки,
  /// а запись голоса и снимок так не теряются: у них свой крестик и «назад».
  void _tapOutside() {
    if (_dock.currentState?.holdsMedia ?? false) return;
    _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final toBackground = ref.read(fileWorkProvider);
    // окно закрывается вместе с движком: большой ролик окно не держит, его доделает фон
    await ref.read(captureServiceProvider).settled().timeout(_fileWait, onTimeout: toBackground);
    await widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(privacyLockProvider).value ?? ref.read(startLockProvider);
    // с кодом на вход или открытым скрытым строка только закидывает: поиск и подсказки обошли бы замок
    final guarded = (lock?.appLock ?? false) || _hiddenOpen;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // рабочий стол под окном затемнён: значки на нём не нажимаются, и выглядеть живыми не должны
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tapOutside,
              child: ColoredBox(key: const ValueKey('quick-shade'), color: Tokens.background.withValues(alpha: 0.5)),
            ),
          ),
          Positioned.fill(
            child: LineDock(key: _dock, onOpenItem: _open, onRest: _finish, writeOnly: guarded),
          ),
        ],
      ),
    );
  }
}
