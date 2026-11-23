import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_language.dart';
import '../../l10n/app_localizations.dart';
import '../../services/panel_bridge.dart';
import '../composer/line_dock.dart' show SendButton;
import 'tab_busy_screen.dart';

/// Боковая панель браузера при открытой вкладке Stowa (STOWA-9). Хранилище держит вкладка,
/// поэтому панель базу не открывает: пишет и ищет через неё по каналу `stowa-panel`.
/// Вкладка не ответила — прежний экран «уже открыта». Отдельное приложение, как
/// [TabBusyApp]: до базы и настроек панель не доходит.
class PanelApp extends StatelessWidget {
  const PanelApp({super.key, required this.client, required this.onOpenHere, this.locale});

  final PanelClient client;

  /// Попросить вкладку уйти; завершается, когда хранилище свободно.
  final Future<void> Function() onOpenHere;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Stowa',
    theme: buildAppTheme(Tokens.palette),
    locale: locale,
    supportedLocales: AppLanguage.supportedLocales,
    localizationsDelegates: const [L.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    localeListResolutionCallback: (deviceLocales, _) => AppLanguage.resolve(deviceLocales ?? const []).locale,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(panelTextScale)), child: child!),
    // панель — бесплатная, как сам сайт: по сути это расширение, поставить его может любой
    home: PanelScreen(client: client, onOpenHere: onOpenHere),
  );
}

/// Сама Stowa открыта в боковой панели браузера (вкладки нет, хранилище у панели): тот же
/// телефонный вид, текст мельче. Обычный узкий сайт на телефоне так не уменьшается —
/// только панель с адресом `?panel` или узкое окно на компьютере.
bool scaledAsPanel(BuildContext context) {
  if (!isWeb) return false;
  if (isPanelAddress()) return true;
  final desktop = switch (defaultTargetPlatform) {
    TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => true,
    _ => false,
  };
  return desktop && isPanelPage();
}

/// Текст в боковой панели мельче телефонного: панель браузера (~340 точек) уже телефона
/// (~390), а вид тот же (хозяин 21.11: «дизайн под телефон уже хороший, только текст меньше»).
const panelTextScale = 0.875;

enum _Link { asking, here, silent }

/// Записанное из панели за этот раз: строка списка с «Отменить».
typedef _Saved = ({String id, String text, String? folder, bool undone});

class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key, required this.client, required this.onOpenHere});

  final PanelClient client;
  final Future<void> Function() onOpenHere;

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  _Link _link = _Link.asking;
  bool _locked = false;
  bool _sending = false;
  bool _leaving = false;
  final _saved = <_Saved>[];

  // поиск: последний ответ и номер вопроса, чтобы старый ответ не затёр свежий
  List<PanelNote>? _found;
  bool _searchLocked = false;
  int _round = 0;
  Timer? _wait;
  String? _note;

  @override
  void initState() {
    super.initState();
    _hello();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  // сколько раз спросить вкладку, прежде чем решить, что она не ответит: панель, которая
  // уступила хранилище перезагруженной вкладке, ждёт, пока та поднимет файлы и базу
  static const _helloTries = 8;

  Future<void> _hello() async {
    Map<String, Object?>? answer;
    for (var attempt = 0; attempt < _helloTries && answer == null && mounted; attempt++) {
      answer = await widget.client.ask('hello');
    }
    if (!mounted) return;
    setState(() {
      _link = answer == null ? _Link.silent : _Link.here;
      _locked = answer?['locked'] == true;
    });
    if (answer != null) _focus.requestFocus();
  }

  String get _query => _field.text.trim();

  void _changed(String _) {
    _wait?.cancel();
    final query = _query;
    setState(() {
      _note = null;
      if (query.length < 2) _found = null;
    });
    if (query.length < 2) return;
    // вкладка ищет по всему хранилищу: ждём, пока допечатают
    _wait = Timer(const Duration(milliseconds: 250), () async {
      final round = ++_round;
      // вкладка в фоне: браузер придерживает её таймеры, на поиск — запас
      final answer = await widget.client.ask('search', payload: {'query': query}, timeout: const Duration(seconds: 5));
      if (!mounted || round != _round || _query != query) return;
      setState(() {
        _searchLocked = answer?['locked'] == true;
        _found = [for (final note in (answer?['notes'] as List?) ?? const []) PanelNote.fromJson(note as Map)];
      });
    });
  }

  Future<void> _send() async {
    final text = _field.text;
    if (_sending || text.trim().isEmpty) return;
    final l = L.of(context);
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    final answer = await widget.client.ask('capture', payload: {'text': text}, timeout: const Duration(seconds: 6));
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (answer?['type'] == 'captured') {
        _saved.insert(0, (id: '${answer!['item']}', text: text.trim(), folder: answer['folder'] as String?, undone: false));
        _field.clear();
        _found = null;
        _note = null;
      } else {
        _note = l.saveFailed;
      }
    });
    _focus.requestFocus();
  }

  Future<void> _undo(_Saved saved) async {
    await widget.client.ask('undo', payload: {'item': saved.id});
    if (!mounted) return;
    setState(() {
      final index = _saved.indexWhere((one) => one.id == saved.id);
      if (index >= 0) _saved[index] = (id: saved.id, text: saved.text, folder: saved.folder, undone: true);
    });
  }

  Future<void> _open(PanelNote note) async {
    final l = L.of(context);
    await widget.client.ask('open', payload: {'item': note.id});
    if (mounted) setState(() => _note = l.panelOpened);
  }

  Future<void> _openHere() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await widget.onOpenHere();
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Ctrl+Enter закидывает, просто Enter — новая строка, как в строке приложения
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && HardwareKeyboard.instance.isControlPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_link == _Link.silent) return TabBusyScreen(onOpenHere: widget.onOpenHere);
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey('panel'),
      backgroundColor: Tokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Stowa', style: text.titleLarge!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w700, fontSize: 20))),
                  TextButton(onPressed: _leaving ? null : _openHere, child: Text(l.tabBusyOpenHere)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Text(l.panelHint, style: text.bodySmall!.copyWith(color: Tokens.muted)),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.emphasizedDecelerate,
                switchOutCurve: Motion.emphasizedAccelerate,
                child: KeyedSubtree(key: ValueKey(_found == null ? 'saved' : 'found'), child: _found == null ? _savedList(l) : _foundList(l)),
              ),
            ),
            if (_note case final note?)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(note, key: const ValueKey('panel-note'), style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
              ),
            _line(l),
          ],
        ),
      ),
    );
  }

  Widget _savedList(L l) {
    final text = Theme.of(context).textTheme;
    if (_saved.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          // под «Кодом на вход» сразу сказать, что искать не выйдет, а записывать — да
          child: Text(_link == _Link.asking ? l.panelWaiting : (_locked ? l.panelLocked : l.panelEmpty), textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: Tokens.muted, height: 1.4)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 8), child: Text(l.panelSaved, style: text.titleSmall!.copyWith(color: Tokens.onSurfaceVariant))),
        for (final saved in _saved)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Row(
              key: ValueKey('panel-saved-${saved.id}'),
              icon: saved.undone ? 'undo' : 'check',
              title: saved.text,
              subtitle: saved.undone ? l.undo : (saved.folder == null ? l.savedToast : l.savedInto(saved.folder!)),
              faded: saved.undone,
              trailing: saved.undone ? null : TextButton(onPressed: () => _undo(saved), child: Text(l.undo)),
            ),
          ),
      ],
    );
  }

  Widget _foundList(L l) {
    final text = Theme.of(context).textTheme;
    final found = _found!;
    if (_searchLocked || found.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(_searchLocked ? l.panelLocked : l.placeSearchNone, textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: Tokens.muted)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        for (final note in found)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _Row(
              key: ValueKey('panel-found-${note.id}'),
              icon: 'description',
              title: note.title.trim().isEmpty ? '…' : note.title,
              subtitle: [?note.line, ?note.folder].join(' · '),
              trailing: Icon(symbolIcon('open_in_new'), size: 18, color: Tokens.muted),
              onTap: () => _open(note),
            ),
          ),
      ],
    );
  }

  // строка как на телефоне (`LineDock`): поле сверху, под ним белая кнопка, подпись
  // «Закинуть» появляется, когда есть что закинуть
  Widget _line(L l) {
    final ready = _query.isNotEmpty && !_sending && _link == _Link.here;
    final fieldStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 16, height: 1.45, color: Tokens.onSurface);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(Radii.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  key: const ValueKey('panel-field'),
                  controller: _field,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _changed,
                  cursorColor: Tokens.accent,
                  style: fieldStyle,
                  decoration: InputDecoration.collapsed(hintText: l.composerHint, hintMaxLines: 1, hintStyle: fieldStyle.copyWith(color: Tokens.muted)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: ready || _sending ? 1 : 0.5,
                duration: Motion.short,
                child: SendButton(
                  key: const ValueKey('panel-send'),
                  label: _query.isEmpty ? '' : l.actionStow,
                  icon: 'arrow_upward',
                  tooltip: l.actionStow,
                  busy: !ready,
                  onTap: _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Строка списка панели: значок, текст и подпись, справа — действие.
class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap, this.faded = false});

  final String icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Tokens.containerHigh,
      borderRadius: BorderRadius.circular(Radii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Icon(symbolIcon(icon), size: 20, color: faded ? Tokens.muted : Tokens.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: faded ? Tokens.muted : Tokens.onSurface)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall!.copyWith(color: Tokens.muted)),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
