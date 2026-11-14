import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion_bits.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/shape_badge.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/tag_tile.dart';
import '../../data/db/database.dart' show Place;
import '../../data/providers.dart';
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/folder_guess.dart' show seriesOf;
import '../../domain/item_kind.dart';
import '../../domain/language_guess.dart';
import '../../domain/line_query.dart';
import '../../domain/models.dart';
import '../../domain/money.dart' show formatTotal;
import '../../domain/note_links.dart' show LinkTarget;
import '../../domain/place_cue.dart' show KnownPlace;
import '../../domain/search_query.dart';
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart';
import '../../services/launch_actions.dart' show LaunchAction;
import '../../core/widgets/undo_snack.dart' show showNote;
import '../folder/folder_sheets.dart';
import '../home/saved_toast.dart';
import '../places/reminder_permissions.dart';
import 'attach_tray.dart';
import 'line_controller.dart';
import 'line_panel.dart';
import 'smart_punctuation.dart';
import 'wiki_link_edit.dart';
import 'wiki_suggestions.dart';
import 'markdown_bar.dart';
import 'markdown_edit.dart';
import 'panel_model.dart';
import 'panel_text.dart';
import 'picked_files.dart';
import 'voice_session.dart';
import 'voice_wave.dart';

const _toastTime = Duration(milliseconds: 3400);

/// Сколько строка раскрывается на весь экран и сворачивается обратно.
const _lineMorph = Duration(milliseconds: 460);
const _searchDelay = Duration(milliseconds: 90);

/// Вложение в строке: грузится, пока крутится значок, потом галочка.
class _Attached {
  _Attached({required this.key, required this.mime, required this.future, this.thumb, this.file});

  final String key;
  final String mime;
  final Future<PickedFile> future;
  final Uint8List? thumb;
  PickedFile? file;
}

class _Toast {
  const _Toast({required this.id, required this.icon, required this.message, this.actionLabel, this.onAction});

  final int id;
  final String icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Живая строка целиком: тень над лентой, плашка «Закинул», панель с поиском
/// и подсказками, галерея, голосовое и редактор на весь экран.
/// Что строка в окне без Activity делает не сама.
class LineElsewhere {
  const LineElsewhere({required this.handOff, required this.micGranted});

  /// Отдать дело окну с Activity вместе с набранным.
  final void Function(LaunchAction action, String text) handOff;

  /// Есть ли право на микрофон: плагин записи без Activity всегда отвечает «нет».
  final Future<bool> Function() micGranted;
}

class LineDock extends ConsumerStatefulWidget {
  const LineDock({super.key, required this.onOpenItem, this.homeFolder, this.onRest, this.writeOnly = false, this.elsewhere});

  final ValueChanged<String> onOpenItem;

  /// Строка внутри папки: кладёт сразу сюда, минуя разбор, и ищет только здесь.
  final FolderCard? homeFolder;

  /// Строка успокоилась: закрыта, пуста, плашка ушла. Окно виджета по этому знаку закрывается.
  final VoidCallback? onRest;

  /// Только закидывать: не искать и не называть ничего из базы — ни заметок, ни папок, ни тегов.
  /// Так работает окно виджета при коде на вход: с рабочего стола строка открыта любому.
  final bool writeOnly;

  /// Строка в окне без Activity (полка «Под рукой»): лоток с камерой и файлами и запрос
  /// микрофона ей недоступны. Вместо них она отдаёт дело сюда вместе с набранным.
  final LineElsewhere? elsewhere;

  @override
  ConsumerState<LineDock> createState() => LineDockState();
}

class LineDockState extends ConsumerState<LineDock> with SingleTickerProviderStateMixin {
  // под замком имена своих мест не показываются: строка узнаёт только виды
  late final LineController _line = LineController(clock: ref.read(clockProvider), workEnd: ref.read(workEndProvider), resolveFolder: _resolveFolder, folderMarks: !widget.writeOnly)
    ..places = widget.writeOnly ? null : _knownPlaces;

  List<KnownPlace> _knownPlaces() => [for (final place in ref.read(placesProvider).value ?? const <Place>[]) (id: place.id, name: place.name, kind: place.kind, label: place.label)];
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  final _undo = UndoHistoryController();
  final _fieldKey = GlobalKey();
  final List<_Attached> _files = [];

  bool _active = false;
  bool _tray = false;
  bool _full = false;
  bool _sending = false;
  VoiceSession? _voice;

  SearchFound _found = SearchFound.none;
  String _searchKey = '';
  Timer? _searchTimer;
  int _searchRun = 0;
  ItemKind? _filter;
  int _selected = 0;
  bool _manual = false;
  PanelState _panel = PanelState.empty;
  int _shownSelected = 0;

  _Toast? _toast;
  Timer? _toastTimer;
  // раскрытие на весь экран: 0 — свёрнута, 1 — во весь экран
  late final AnimationController _morph = AnimationController(vsync: this, duration: _lineMorph)
    ..addStatusListener((_) {
      // панель подсказок ждёт, пока строка доедет, чтобы не выскочить посреди движения
      if (mounted) setState(() {});
    });
  final _cardKey = GlobalKey();
  double? _compactHeight;
  int _toastCount = 0;

  String? _clip;

  /// В буфере есть текст, но строка в окне поверх его не читала: прочтёт по касанию.
  bool _clipUnread = false;
  AssetEntity? _shot;
  Uint8List? _shotThumb;
  final _usedSuggestions = <String>{};
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _line.chooseFolder(widget.homeFolder);
    _line.addListener(_onLine);
    _focus.addListener(_onFocus);
    unawaited(_cleanVoiceDrafts().catchError((_) {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // поверх открыли заметку или настройки — фокус уходит. Иначе при возврате Flutter вернёт его
    // строке сам, и вылезет клавиатура: на Android «назад» прячет клавиатуру, а фокус оставляет
    if (ModalRoute.isCurrentOf(context) == false && _focus.hasFocus) _focus.unfocus();
  }

  Future<void> _cleanVoiceDrafts() async {
    final db = ref.read(databaseProvider);
    final waiting = {for (final job in await db.select(db.fileJobs).get()) job.source};
    await cleanVoiceDrafts(_voiceFolder, DateTime.now(), waiting: waiting);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _toastTimer?.cancel();
    _morph.dispose();
    _voice?.dispose();
    _line.dispose();
    _focus.dispose();
    _undo.dispose();
    super.dispose();
  }

  Directory get _voiceFolder => Directory(p.join(ref.read(scratchRootProvider).path, 'tmp'));

  DateTime get _now => ref.read(clockProvider)();

  bool get _hasContent => _line.text.trim().isNotEmpty || _files.isNotEmpty;

  bool get _rested => !_active && _toast == null && _voice == null && !_sending && !_hasContent;
  bool _wasRested = true;

  // сама по пробелу встаёт только папка с точно таким именем; по началу имени выбирают в панели,
  // иначе «@Беспроводные » схватит «Беспроводные наушники» и новую папку не создать
  FolderCard? _resolveFolder(String name) {
    // по вставшему чипу было бы видно, что такая папка есть
    if (widget.writeOnly) return null;
    final folders = ref.read(foldersProvider).value ?? const [];
    return folders.where((folder) => normalizeQuery(folder.name) == name).firstOrNull;
  }

  void _onFocus() {
    if (_focus.hasFocus && !_active) {
      setState(() {
        _active = true;
        _tray = false;
      });
      _loadSuggestions();
    } else {
      setState(() {});
    }
  }

  void _onLine() {
    _manual = false;
    if (_line.text.isEmpty) _filter = null;
    _scheduleSearch();
    // заметки для подсказки [[… читаются один раз, когда курсор впервые встал в скобки
    if (_wikiQuery != null && _linkTargets == null) {
      _linkTargets = const [];
      ref.read(itemsRepositoryProvider).linkTargets().then((targets) {
        if (mounted) setState(() => _linkTargets = targets);
      }).ignore();
    }
    setState(() {});
  }

  List<LinkTarget>? _linkTargets;

  /// Набранное в [[… под курсором; под замком подсказки нет — строка ничего из базы не показывает.
  String? get _wikiQuery => widget.writeOnly || !_focus.hasFocus ? null : wikiQueryOf(_line.value);

  void _pickWiki(LinkTarget target) {
    _line.value = completeWikiLink(_line.value, target.title);
    _focus.requestFocus();
  }

  /// «Создать заметку «…»»: заметка с этим заголовком заводится сразу, ссылка в строке закрывается.
  Future<void> _createWiki(String title) async {
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: title, detectReminder: false, detectPlace: false, here: false));
    if (!mounted) return;
    _linkTargets = [...?_linkTargets, (id: id, title: title, text: title, at: ref.read(clockProvider)(), kind: ItemKind.note)];
    _line.value = completeWikiLink(_line.value, title);
    _focus.requestFocus();
  }

  // поиск идёт по словам без команды, тегов и папок; чипы — фильтр
  void _scheduleSearch() {
    if (!mounted || widget.writeOnly) return;
    final caret = _line.selection.isValid ? _line.selection.extentOffset : _line.text.length;
    if (caretToken(_line.text, caret) != null) return;
    final query = queryOf(_line.text, commandKeys(L.of(context)));
    final search = parseSearch(query.free, _now);
    final key = '${query.free.toLowerCase()}|${_line.tags.join(' ')}|${_line.folder?.id}';
    if (key == _searchKey) return;
    _searchKey = key;
    _searchTimer?.cancel();
    if (search.isEmpty && _line.tags.isEmpty && _line.folder == null) {
      _found = SearchFound.none;
      return;
    }
    final run = ++_searchRun;
    _searchTimer = Timer(_searchDelay, () async {
      // «рядом» спрашивает, где телефон, только когда его попросили
      final here = search.near ? await ref.read(searchHereProvider)() : null;
      if (!mounted || run != _searchRun) return;
      final found = await ref.read(itemsRepositoryProvider).search(query: search, tags: _line.tags, folderId: _line.folder?.id, now: _now, here: here);
      if (mounted && run == _searchRun) setState(() => _found = found);
    });
  }

  Future<void> _loadSuggestions() async {
    if (_line.text.isNotEmpty) return;
    // в полке «Под рукой» буфер не читается сам: Android сообщает о каждом чтении. Спрашиваем
    // только, есть ли там текст (без сообщения), а читаем по касанию подсказки
    if (widget.elsewhere != null) {
      final has = await Clipboard.hasStrings().catchError((_) => false);
      if (mounted) setState(() => _clipUnread = has);
      return;
    }
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final url = firstUrl(text);
      final clip = url == null || _usedSuggestions.contains(text) ? null : (text.length < 300 ? text : url.toString());
      if (mounted) setState(() => _clip = clip);
    } catch (_) {
      // буфер недоступен: подсказки просто не будет
    }
    try {
      final permission = await PhotoManager.getPermissionState(requestOption: const PermissionRequestOption());
      if (!permission.hasAccess) return;
      final latest = await PhotoManager.getAssetListRange(
        start: 0,
        end: 1,
        type: RequestType.image,
        filterOption: FilterOptionGroup(orders: const [OrderOption()]),
      );
      final shot = latest.firstOrNull;
      final where = '${shot?.relativePath ?? ''} ${shot?.title ?? ''}'.toLowerCase();
      if (shot == null ||
          _usedSuggestions.contains(shot.id) ||
          !where.contains('screenshot') ||
          _now.difference(shot.createDateTime) > const Duration(minutes: 30)) {
        return;
      }
      // скриншот уже сохранили из галереи: второй раз не зовём
      final items = ref.read(itemsRepositoryProvider);
      final name = shot.title ?? '';
      if (name.isNotEmpty && (await items.hasPicture(name, shot.width, shot.height) || await items.hasPicture(name, shot.height, shot.width))) {
        return;
      }
      final thumb = await galleryThumb(shot);
      if (mounted) {
        setState(() {
          _shot = shot;
          _shotThumb = thumb;
        });
      }
    } catch (_) {
      // галерея недоступна: без подсказки скриншота
    }
  }

  void _activate() {
    if (!_active) _loadSuggestions();
    setState(() => _active = true);
  }

  /// Касание закреплённого тега: строка открывается с его чипом и сразу показывает вещи с ним.
  /// Кнопка «Искать» на экране папки: строка просыпается с клавиатурой.
  void focusLine() {
    _activate();
    _focus.requestFocus();
  }

  /// Микрофон виджета: запись начинается сразу, без касания строки. false — записи нет.
  Future<bool> startVoice() async => _voice != null || await _startVoice();

  /// Палец отпустил корешки «Под рукой»: идущая запись сохраняется, как второй кнопкой.
  Future<void> finishVoice() async {
    if (_voice != null) await _stopVoice(keep: true);
  }

  /// Камера виджета: готовый снимок встаёт вложением.
  void attach(List<PickedFile> files) => _addPicked(files);

  /// Набранное в другом окне (полка «Под рукой») продолжается здесь.
  void prefill(String text) {
    _line.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _activate();
  }

  /// «+» полки: лоток вложений сразу открыт.
  void openTray() {
    if (!_tray) _toggleTray();
  }

  /// В строке запись голоса или вложения: заново их не наберёшь, случайное касание терять не должно.
  bool get holdsMedia => _voice != null || _files.isNotEmpty;

  void searchTag(String name) {
    _line.reset();
    _line.addTag(name);
    _activate();
    _focus.requestFocus();
  }

  void _deactivate() {
    _focus.unfocus();
    setState(() {
      _active = false;
      _tray = false;
      _full = false;
    });
  }

  void _showToast(String icon, String message, {String? actionLabel, VoidCallback? onAction}) {
    _toastTimer?.cancel();
    final id = ++_toastCount;
    setState(() => _toast = _Toast(id: id, icon: icon, message: message, actionLabel: actionLabel, onAction: onAction));
    _toastTimer = Timer(_toastTime, () {
      if (mounted && _toast?.id == id) setState(() => _toast = null);
    });
  }

  void _hideToast() {
    _toastTimer?.cancel();
    setState(() => _toast = null);
  }

  // ———————————————— вложения

  void _addPicked(List<PickedFile> picked) {
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final file in picked) {
        _files.add(_Attached(key: file.path, mime: file.mime, future: Future.value(file), file: file));
      }
      _active = true;
    });
  }

  Future<void> _pick(Future<List<PickedFile>> Function() picker) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      _addPicked(await picker());
    } on PlatformException {
      messenger.showSnackBar(SnackBar(content: Text(l.attachFailed)));
    }
  }

  void _toggleAsset(AssetEntity asset, Uint8List? thumb) {
    final index = _files.indexWhere((file) => file.key == asset.id);
    if (index >= 0) {
      setState(() => _files.removeAt(index));
      return;
    }
    final mime = asset.mimeType ?? (asset.type == AssetType.video ? 'video/mp4' : 'image/jpeg');
    final attached = _Attached(key: asset.id, mime: mime, thumb: thumb, future: _resolveAsset(asset));
    setState(() => _files.add(attached));
    attached.future
        .then((file) {
          if (mounted) setState(() => attached.file = file);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _files.remove(attached));
        });
  }

  Future<PickedFile> _resolveAsset(AssetEntity asset) async {
    final file = await asset.originFile ?? await asset.file;
    if (file == null) throw StateError('файл недоступен');
    return pickedFrom(file.path, hint: asset.mimeType);
  }

  Future<void> _pasteLink() async {
    final l = L.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = firstUrl(data?.text ?? '');
    if (url == null) {
      _showToast('link_off', l.trayNoLink);
      return;
    }
    _line.insertAtCaret(url.toString());
    setState(() => _tray = false);
    _focus.requestFocus();
  }

  Future<void> _useClip() async {
    if (_clipUnread) {
      setState(() => _clipUnread = false);
      final data = await Clipboard.getData(Clipboard.kTextPlain).catchError((_) => null);
      final text = data?.text?.trim() ?? '';
      if (!mounted || text.isEmpty) return;
      _line.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      _focus.requestFocus();
      return;
    }
    final clip = _clip;
    if (clip == null) return;
    _usedSuggestions.add(clip);
    setState(() => _clip = null);
    _line.value = TextEditingValue(
      text: clip,
      selection: TextSelection.collapsed(offset: clip.length),
    );
    _focus.requestFocus();
  }

  void _useShot() {
    final shot = _shot;
    if (shot == null) return;
    _usedSuggestions.add(shot.id);
    setState(() => _shot = null);
    _toggleAsset(shot, _shotThumb);
  }

  /// Запрос с фильтром — умной папкой на главную: имя по умолчанию сам запрос с заглавной.
  Future<void> _saveSmart() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final query = _line.text.trim();
    if (query.isEmpty) return;
    final name = await showRenameSheet(context, '${query[0].toUpperCase()}${query.substring(1)}');
    if (name == null || !mounted) return;
    await ref.read(smartFoldersRepositoryProvider).create(name: name, query: query);
    showNote(messenger, l.smartSaved(name.trim()), overDock: true);
  }

  // ———————————————— действия

  Future<void> _act() async {
    if (_voice != null) return _stopVoice(keep: true);
    if (_full || _tray) {
      if (_hasContent) await _save();
      return;
    }
    final rows = _panel.rows;
    if (rows.isNotEmpty) return _actRow(rows[_shownSelected.clamp(0, rows.length - 1)]);
    if (_hasContent) return _save();
    await _startVoice();
  }

  Future<void> _actRow(PanelRow row) async {
    final caret = _line.selection.isValid ? _line.selection.extentOffset : _line.text.length;
    final token = caretToken(_line.text, caret);
    switch (row) {
      case SaveRow():
        await _save();
      case ResultRow(:final result):
        _open(result.card.id);
      case TagRow(:final tag):
        if (token != null) _line.replaceRange(token.start, token.end, '');
        _line.addTag(tag.name);
      case NewTagRow(:final name):
        if (token != null) _line.replaceRange(token.start, token.end, '');
        _line.addTag(name);
      case FolderRow(:final folder):
        if (token != null) _line.replaceRange(token.start, token.end, '');
        _line.chooseFolder(folder);
      case NewFolderRow(:final name):
        if (token != null) _line.replaceRange(token.start, token.end, '');
        _line.chooseFolder(await ref.read(foldersRepositoryProvider).create(name));
      case CommandRow(key_: final key):
        if (token != null) _line.replaceRange(token.start, token.end, '/$key ');
    }
  }

  void _open(String id) {
    _deactivate();
    widget.onOpenItem(id);
  }

  /// Подсказку про чужой язык скрыли крестиком: до следующей заметки она не вернётся.
  bool _languageHidden = false;

  void _clearLine() {
    _languageHidden = false;
    _line.reset();
    // в папке строка и дальше кладёт сюда
    _line.chooseFolder(widget.homeFolder);
    _undo.value = UndoHistoryValue.empty;
    _files.clear();
    _found = SearchFound.none;
    _searchKey = '';
    _filter = null;
  }

  Future<void> _save() async {
    if (_sending || !_hasContent) return;
    final l = L.of(context);
    // «Отменить» вернёт строку такой, какой её набрали, с метками в тексте
    final typed = (text: _line.text, tags: _line.tags, folder: _line.folder);
    final newFolder = _line.takeMarks();
    final query = queryOf(_line.text, commandKeys(l));
    final command = query.command;
    final rest = query.rest;
    final body = switch (command) {
      LineCommand.list => checklistBody(checklistItems(rest)),
      LineCommand.task => '- [ ] ${rest.trim()}',
      _ => rest,
    };
    final snapshot = (text: typed.text, tags: typed.tags, folder: typed.folder, dismissed: _line.reminderDismissed, placeDismissed: _line.placeDismissed, files: List.of(_files));
    final reminderAt = _line.reminder?.at;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();
    try {
      if (newFolder != null) _line.chooseFolder(await ref.read(foldersRepositoryProvider).create(newFolder));
      final files = await Future.wait(_files.map((file) => file.future));
      final capture = ref.read(captureServiceProvider);
      final id = await capture.capture(
        CaptureInput(
          text: body,
          files: files,
          forcedFolderId: _line.folder?.id,
          forcedTagNames: _line.tags,
          detectReminder: !_line.reminderDismissed,
          detectPlace: !_line.placeDismissed,
          asIs: command == LineCommand.inbox,
          untitled: files.isEmpty ? null : (at) => untitledFor(l, mime: files.first.mime, fileName: p.basename(files.first.path), at: at),
        ),
      );
      if (_clip != null && snapshot.text.contains(_clip!)) _usedSuggestions.add(_clip!);
      final saved = await ref.read(itemsRepositoryProvider).get(id);
      // «только закинуть» кладёт по правилам, но куда легло — не говорит
      final folders = widget.writeOnly ? const <FolderCard>[] : ref.read(foldersProvider).value ?? const [];
      final folder = folders.where((one) => one.id == saved?.item.folderId).firstOrNull;
      if (!mounted) return;
      final when = reminderAt == null ? null : formatReminder(l, reminderAt, _now);
      final message = folder != null
          ? (when != null ? l.savedIntoRemind(folder.name, when) : l.savedInto(folder.name))
          : (when != null ? l.savedWithReminder(when) : l.savedToast);
      _clearLine();
      _deactivate();
      _showToast(
        'check',
        message,
        actionLabel: l.undo,
        onAction: () async {
          // текст возвращается до того, как уйдёт плашка: пустой и закрытой строка не бывает ни кадра
          _files
            ..clear()
            ..addAll(snapshot.files);
          _line.restore(text: snapshot.text, tags: snapshot.tags, folder: snapshot.folder, reminderDismissed: snapshot.dismissed, placeDismissed: snapshot.placeDismissed);
          _activate();
          _focus.requestFocus();
          _hideToast();
          await ref.read(itemsRepositoryProvider).softDelete(id, _now);
        },
      );
      // поставил напоминание — тут и спросить уведомления; про место «всегда» скажет карточка на главной
      if (saved?.item.reminderAt != null || saved?.item.remindPlace != null) askNotifications(ref).ignore();
    } catch (_) {
      // не сохранилось: строка снова такая, как её набрали
      _line.restore(text: typed.text, tags: typed.tags, folder: typed.folder, reminderDismissed: snapshot.dismissed, placeDismissed: snapshot.placeDismissed);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.saveFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _append(ResultRow row) async {
    final l = L.of(context);
    final rest = queryOf(_line.text, commandKeys(l)).rest.trim();
    if (rest.isEmpty) return;
    final text = rest[0].toUpperCase() + rest.substring(1);
    final card = row.result.card;
    await ref.read(itemsRepositoryProvider).append(card.id, text, _now);
    if (!mounted) return;
    _clearLine();
    _deactivate();
    _showToast(
      'edit_note',
      l.appendedTo(card.title),
      actionLabel: l.actionOpen,
      onAction: () {
        widget.onOpenItem(card.id);
        _hideToast();
      },
    );
  }

  Future<bool> _startVoice() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final elsewhere = widget.elsewhere;
    // без Activity спросить микрофон некому: с правом пишем здесь, без него — в окне виджета
    if (elsewhere != null && !await elsewhere.micGranted()) {
      _handOff(LaunchAction.voice);
      return false;
    }
    final session = VoiceSession(_voiceFolder);
    var started = false;
    try {
      started = await session.start(checked: elsewhere != null);
    } catch (_) {
      started = false;
    }
    if (!started) {
      session.dispose();
      if (elsewhere != null) {
        _handOff(LaunchAction.voice);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.voiceDenied)));
      }
      return false;
    }
    HapticFeedback.mediumImpact();
    session.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _voice = session;
      _active = true;
      _tray = false;
    });
    return true;
  }

  Future<void> _stopVoice({required bool keep}) async {
    final session = _voice;
    if (session == null) return;
    setState(() => _voice = null);
    if (!keep) {
      await session.cancel();
      session.dispose();
      return;
    }
    final l = L.of(context);
    final file = await session.stop();
    session.dispose();
    if (file == null || !mounted) return;
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(files: [file], title: l.voiceTitle));
    if (!mounted) return;
    _deactivate();
    _showToast(
      'graphic_eq',
      l.voiceSaved,
      actionLabel: l.undo,
      onAction: () async {
        // плашка уходит после удаления: окно виджета закрывается вслед за ней
        await ref.read(itemsRepositoryProvider).softDelete(id, _now);
        if (mounted) _hideToast();
      },
    );
  }

  void _toggleTray() {
    final open = !_tray;
    if (open && widget.elsewhere != null) return _handOff(LaunchAction.attach);
    if (open) _focus.unfocus();
    setState(() {
      _tray = open;
      _full = false;
      if (open) _active = true;
    });
  }

  /// Дело уходит в другое окно вместе с набранным: здесь строка пустеет, иначе то же
  /// сохранилось бы второй раз следующим касанием кнопки.
  void _handOff(LaunchAction action) {
    final text = _line.text;
    _line.clear();
    _focus.unfocus();
    setState(() => _active = false);
    widget.elsewhere?.handOff(action, text);
  }

  void _setFull(bool on) {
    if (on == _full) return;
    // высота свёрнутой строки снимается до раскрытия: к ней строка и вернётся
    final card = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (on && card != null && card.hasSize) _compactHeight = card.size.height;
    setState(() {
      _full = on;
      if (on) {
        _active = true;
        _tray = false;
      }
    });
    // анимация всегда идёт вперёд от начала: и раскрытие, и сворачивание трогаются сразу
    // и мягко садятся, а не играют одну кривую задом наперёд
    _morph.forward(from: 0);
    if (on) _focus.requestFocus();
  }

  void _markdown(MarkdownAction action) {
    _line.value = applyMarkdown(_line.value, action);
  }

  void _insertGlyph(String glyph) {
    if (glyph == '/') {
      // команда живёт только в начале строки
      final text = _line.text;
      final next = text.startsWith('/') ? text : (text.isEmpty ? '/' : '/ $text');
      _line.value = TextEditingValue(text: next, selection: const TextSelection.collapsed(offset: 1));
    } else {
      _line.insertAtCaret(glyph);
    }
    _focus.requestFocus();
  }

  void _move(int step) {
    if (_panel.rows.isEmpty) return;
    setState(() {
      _selected = (_shownSelected + step).clamp(0, _panel.rows.length - 1);
      _manual = true;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final collapsedAtStart = _line.selection.isCollapsed && _line.selection.baseOffset == 0;
    if (key == LogicalKeyboardKey.backspace && collapsedAtStart && _line.dropLastChip()) return KeyEventResult.handled;
    if (_full) {
      if (key == LogicalKeyboardKey.escape) {
        _setFull(false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if ((key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) && _panel.rows.isNotEmpty) {
      _move(key == LogicalKeyboardKey.arrowUp ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && !shift) {
      _act();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab && _panel.rows.isNotEmpty) {
      _actRow(_panel.rows[_shownSelected]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_tray) {
        _toggleTray();
      } else if (_line.text.isNotEmpty) {
        _line.clear();
      } else {
        _deactivate();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ———————————————— экран

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final now = _now;
    final caret = _line.selection.isValid ? _line.selection.extentOffset : _line.text.length;
    final keys = commandKeys(l);
    // «только закинуть» базу не читает: ни теги, ни папки, ни правила в панель не попадают
    final shows = !widget.writeOnly;
    _panel = buildPanel(
      PanelInput(
        text: _line.text,
        caret: caret,
        commandKeys: keys,
        chosenTags: _line.tags,
        chosenFolder: _line.folder,
        attachmentMimes: [for (final file in _files) file.mime],
        tags: shows ? ref.watch(allTagsProvider).value ?? const [] : const [],
        folders: shows ? ref.watch(foldersProvider).value ?? const [] : const [],
        rules: shows ? ref.watch(rulesProvider).value ?? const [] : const [],
        found: _found.results,
        // «Ищу: потратил на · Ремонт · 23 150 лей»
        understood: _found.query.hasFilters
            ? [..._found.query.understood, ?_found.spentFolder, if (_found.total.isNotEmpty) formatTotal(_found.total, L.of(context).localeName)]
            : const [],
        filter: _filter,
        remindAt: _line.reminder?.at,
        folderIndex: shows ? ref.watch(folderIndexProvider).value : null,
        // две прошлые заметки подряд в одной папке: подсказка видит серию, как и сохранение
        series: shows ? seriesOf([for (final card in (ref.watch(recentItemsProvider).value ?? const []).take(2)) (folderId: card.folderId, at: card.createdAt)], now) : null,
        writeOnly: widget.writeOnly,
      ),
    );
    final rows = _panel.rows;
    _shownSelected = !_manual || _selected >= rows.length ? _panel.pick : _selected;
    // курсор в [[…: над полем список заметок, поиск строки не мешает
    final showPanel = _active && !_full && !_morph.isAnimating && _voice == null && _wikiQuery == null && (_tray || rows.isNotEmpty);
    final shade = showPanel || _full;
    final rest = queryOf(_line.text, keys).rest;
    // знак «успокоилась» уходит после кадра: плашка, вставшая следом за закрытием, его отменяет
    final rested = _rested;
    if (rested && !_wasRested && widget.onRest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _rested) widget.onRest?.call();
      });
    }
    _wasRested = rested;

    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_voice != null) {
          _stopVoice(keep: false);
        } else if (_full) {
          _setFull(false);
        } else {
          _deactivate();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !shade,
              child: AnimatedOpacity(
                opacity: shade ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                curve: Motion.emphasized,
                child: GestureDetector(
                  onTap: _full ? () => _setFull(false) : _deactivate,
                  child: ColoredBox(color: Tokens.background.withValues(alpha: 0.72), child: const SizedBox.expand()),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_full) _toastView(),
                      // в редакторе на весь экран панели нет, строка забирает всю высоту
                      if (!_full)
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            reverseDuration: const Duration(milliseconds: 180),
                            switchInCurve: Motion.spatial,
                            switchOutCurve: Motion.emphasizedAccelerate.flipped,
                            layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomCenter, children: [...previous, ?current]),
                            transitionBuilder: riseTransition,
                            child: !showPanel
                                ? const SizedBox(key: ValueKey('none'), width: double.infinity)
                                : Padding(
                                    key: ValueKey(_tray ? 'tray' : 'panel'),
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _tray
                                        ? Container(
                                            decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(Radii.card)),
                                            padding: const EdgeInsets.all(6),
                                            child: AttachTray(
                                              selected: [for (final file in _files) file.key],
                                              onToggle: _toggleAsset,
                                              onCamera: () => _pick(pickCameraPhoto),
                                              onVideo: () => _pick(pickCameraVideo),
                                              onFiles: () => _pick(pickAnyFiles),
                                              onLink: _pasteLink,
                                            ),
                                          )
                                        : LinePanel(
                                            state: _panel,
                                            selected: _shownSelected,
                                            rest: rest,
                                            now: now,
                                            filesRoot: ref.watch(filesRootProvider),
                                            filter: _filter,
                                            onFilter: (kind) => setState(() {
                                              _filter = kind;
                                              _manual = false;
                                            }),
                                            onTap: (index) => _actRow(rows[index]),
                                            onAppend: _append,
                                            onSmartFolder: _found.query.hasFilters && _found.results.isNotEmpty ? _saveSmart : null,
                                          ),
                                  ),
                          ),
                        ),
                      // раскрытие и сворачивание ведёт сама высота карточки, кадр за кадром,
                      // пружинкой макета в обе стороны; выше экрана перелёт не пускаем
                      AnimatedBuilder(
                        animation: _morph,
                        builder: (context, child) {
                          final compact = _compactHeight ?? 0;
                          final from = _full ? compact : constraints.maxHeight;
                          final to = _full ? constraints.maxHeight : compact;
                          final height = _full || _morph.isAnimating
                              // ниже свёрнутой высоты не проваливается: туда не влезает содержимое
                              ? (from + (to - from) * Motion.spatial.transform(_morph.value)).clamp(compact, constraints.maxHeight)
                              : null;
                          return SizedBox(key: _cardKey, height: height, child: child);
                        },
                        child: _composer(l, now),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toastView() {
    final toast = _toast;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 200),
      switchInCurve: Motion.spatial,
      switchOutCurve: Motion.emphasizedAccelerate.flipped,
      transitionBuilder: riseTransition,
      child: toast == null
          ? const SizedBox(key: ValueKey('no-toast'), width: double.infinity)
          : Padding(
              key: ValueKey(toast.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: SavedToast(icon: toast.icon, message: toast.message, actionLabel: toast.actionLabel, onAction: toast.onAction),
            ),
    );
  }

  Widget _composer(L l, DateTime now) {
    final text = Theme.of(context).textTheme;
    final chips = _chips(l, now);
    final fieldStyle = text.bodyLarge!.copyWith(fontSize: 16, height: 1.45, color: Tokens.onSurface);
    final field = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: TextField(
        controller: _line,
        focusNode: _focus,
        undoController: _undo,
        minLines: _full ? null : 1,
        maxLines: _full ? null : 6,
        expands: _full,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textInputAction: _full ? TextInputAction.newline : TextInputAction.send,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _act(),
        // строка не теряет фокус после «Вставить», клавиатура остаётся
        onEditingComplete: () {},
        onTap: _activate,
        cursorColor: Tokens.accent,
        style: fieldStyle,
        // второй «[» дописывает «]]»; под замком подсказки нет, но скобки закрываются; << >> -- — в « » —
        inputFormatters: [TextInputFormatter.withFunction(closeWikiBrackets), TextInputFormatter.withFunction(smartPunctuation)],
        decoration: InputDecoration.collapsed(
          hintText: _full ? l.fullHint : (widget.homeFolder != null ? l.dropHere : (widget.writeOnly ? l.composerHintNoSearch : l.composerHint)),
          hintMaxLines: _full ? null : 1,
          hintStyle: fieldStyle.copyWith(color: Tokens.muted),
        ),
      ),
    );

    // фон со скруглёнными углами снаружи, рамка роста внутри: растёт сама карточка, как height
    // в макете (0,46 с пружинкой), а не обрезанная рамкой копия с плоскими углами
    return AnimatedContainer(
      key: const ValueKey('composer'),
      duration: const Duration(milliseconds: 250),
      curve: Motion.emphasized,
      transform: Matrix4.translationValues(0, _drag * 0.35, 0),
      decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(Radii.card)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        // во время раскрытия высоту ведёт сама анимация раскрытия; ноль Flutter не принимает
        duration: _full || _morph.isAnimating ? const Duration(milliseconds: 1) : const Duration(milliseconds: 460),
        curve: Motion.spatial,
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: _full ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _grip(l),
              // панель разметки выезжает за 0,42 с, когда строка уже раскрылась, и уходит сразу
              // при сворачивании: пока строка едет, ей не хватает места
              AnimatedSize(
                duration: _full ? const Duration(milliseconds: 420) : const Duration(milliseconds: 1),
                curve: Motion.emphasized,
                child: AnimatedOpacity(
                  opacity: _full && !_morph.isAnimating ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: _full && !_morph.isAnimating ? MarkdownBar(onAction: _markdown, undo: _undo) : const SizedBox(width: double.infinity),
                ),
              ),
              // рост под чипы ведёт рамка всей строки; край не маской (она перерисовывает слой
              // каждый кадр и рвёт анимацию на телефоне), а наложенным градиентом цвета строки
              // чужой язык, а ни время, ни место не нашлись: время цифрами понимается на любом.
              // Строкой, а не чипом: длинный текст в ряду чипов увёл бы крестик за край
              if (!_languageHidden && _line.reminder == null && _line.placeCue == null && unsupportedLanguage(_line.text))
                _LanguageHint(text: l.lineLanguageHint, hideTooltip: l.lineLanguageHide, onHide: () => setState(() => _languageHidden = true)),
              if (_wikiQuery case final query?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                  child: WikiSuggestions(query: query, targets: _linkTargets ?? const [], onPick: _pickWiki, onCreate: _createWiki, maxHeight: 232),
                ),
              if (chips.isNotEmpty)
                Stack(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(4, 2, 24, 8),
                      child: Row(
                        children: [for (final chip in chips) Padding(padding: const EdgeInsets.only(right: 8), child: chip)],
                      ),
                    ),
                    Positioned(top: 0, bottom: 0, right: 0, width: 28, child: EdgeFade(color: Tokens.containerHighest, toRight: true)),
                  ],
                ),
              // поле всегда в одном и том же месте дерева: иначе Flutter пересоздаёт его,
              // фокус теряется, клавиатура уходит
              Flexible(
                fit: _full ? FlexFit.tight : FlexFit.loose,
                child: Visibility(
                  visible: _voice == null,
                  maintainState: true,
                  child: KeyedSubtree(key: _fieldKey, child: field),
                ),
              ),
              _controls(l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grip(L l) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setFull(!_full),
      onVerticalDragUpdate: (details) => setState(() => _drag = (_drag + details.delta.dy).clamp(-40, 40)),
      onVerticalDragEnd: (_) {
        final drag = _drag;
        setState(() => _drag = 0);
        // вверх раскрывает, вниз сворачивает
        if (drag < -24 && !_full) _setFull(true);
        if (drag > 24 && _full) _setFull(false);
      },
      child: Semantics(
        button: true,
        label: _full ? l.fullCollapse : l.fullExpand,
        child: SizedBox(
          height: 16,
          child: Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(color: Tokens.outline, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _chips(L l, DateTime now) {
    final chips = <Widget>[];
    // своя папка экрана чипом не висит: и так видно, где находишься
    final folder = _line.folder?.id == widget.homeFolder?.id ? null : _line.folder;
    final plan = _panel.plan;
    if (folder != null) {
      chips.add(
        _LineChip(
          key: ValueKey('f${folder.id}'),
          leading: ShapeBadge(
            shape: BadgeShape.values.asNameMap()[folder.shape] ?? BadgeShape.squircle,
            size: 26,
            color: Tokens.accent,
            child: Icon(symbolIcon(folder.icon, filled: true), size: 16, color: Tokens.onAccent),
          ),
          label: folder.name,
          removeTooltip: l.removeChip,
          onRemove: () => _line.chooseFolder(null),
        ),
      );
    } else if (_full && !_morph.isAnimating && _line.folder == null && !widget.writeOnly) {
      // догадки редактора появляются, когда строка раскрылась: пока едет, им нет места
      final guess = plan?.folder;
      chips.add(_DestChip(key: const ValueKey('dest'), icon: guess?.icon ?? 'inbox', label: guess?.name ?? l.fullPickFolder, onTap: _pickFolder));
    }
    // свой значок у чипа выдал бы, что тег уже есть
    final tags = [if (!widget.writeOnly) ...?ref.watch(allTagsProvider).value];
    final filesRoot = ref.watch(filesRootProvider);
    for (final name in _line.tags) {
      final tag = tags.where((one) => one.name == name).firstOrNull;
      chips.add(
        _LineChip(
          key: ValueKey('#$name'),
          leading: TagTile(kind: tag?.iconKind ?? TagIconKind.symbol, value: tag?.iconValue ?? 'tag', filesRoot: filesRoot, size: 26),
          label: name,
          removeTooltip: l.removeChip,
          onRemove: () => _line.removeTag(name),
        ),
      );
    }
    if (_full && !_morph.isAnimating && plan != null) {
      // теги, которые строка поставит сама: пунктиром, касание закрепляет
      for (final tag in plan.autoTags) {
        chips.add(_AutoChip(key: ValueKey('a$tag'), label: tag, tooltip: l.pinTag, onTap: () => _line.addTag(tag)));
      }
    }
    final reminder = _line.reminder;
    if (reminder != null) {
      chips.add(
        _LineChip(
          key: const ValueKey('reminder'),
          leading: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(9)),
            child: Icon(symbolIcon('alarm', filled: true), size: 17, color: Tokens.onAccent),
          ),
          label: l.composerRemind(formatReminder(l, reminder.at, now)),
          removeTooltip: l.composerRemoveReminder,
          onRemove: _line.dismissReminder,
        ),
      );
    }
    final place = _line.placeCue;
    if (place != null) {
      chips.add(
        _LineChip(
          key: const ValueKey('place'),
          leading: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(9)),
            child: Icon(symbolIcon('location_on', filled: true), size: 17, color: Tokens.onAccent),
          ),
          label: remindPlaceLabel(l, place.kind, name: place.placeName, day: _line.placeDay, now: _now),
          removeTooltip: l.composerRemovePlace,
          onRemove: _line.dismissPlace,
        ),
      );
    }
    for (final file in _files) {
      chips.add(_AttachmentTile(key: ValueKey('p${file.key}'), attached: file, tooltip: l.removeAttachment, onTap: () => setState(() => _files.remove(file))));
    }
    final suggest = chips.isEmpty && _active && !_full && !_tray && _voice == null && _line.text.isEmpty;
    if (suggest && (_clip != null || _clipUnread)) {
      final address = _clip == null ? null : firstUrl(_clip!)?.host;
      final host = address == null ? '' : sourceName(address);
      chips.add(
        _Suggestion(
          key: const ValueKey('sclip'),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
            child: Icon(symbolIcon('content_paste'), size: 18, color: Tokens.onAccent),
          ),
          label: _clip == null ? l.suggestPaste : l.suggestClip,
          hint: host,
          onTap: _useClip,
        ),
      );
    }
    if (suggest && _shot != null) {
      final minutes = now.difference(_shot!.createDateTime).inMinutes;
      chips.add(
        _Suggestion(
          key: const ValueKey('sshot'),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 32,
              child: _shotThumb == null ? ColoredBox(color: Tokens.graphite) : Image.memory(_shotThumb!, fit: BoxFit.cover),
            ),
          ),
          label: l.suggestShot,
          hint: minutes < 1 ? l.justNow : l.minutesAgo(minutes),
          onTap: _useShot,
        ),
      );
    }
    return chips;
  }

  Future<void> _pickFolder() async {
    final l = L.of(context);
    final folders = ref.read(foldersProvider).value ?? const [];
    // лист перекрывает строку и снимает с неё фокус; набирали — набор продолжается после выбора
    final typing = _focus.hasFocus;
    final picked = await showOptionsSheetWith<FolderCard?>(
      context,
      (sheet) => FolderPickerSheet(title: l.folderPickTitle, folders: folders, onNew: () => askNewFolder(sheet, ref)),
    );
    if (picked != null) _line.chooseFolder(picked);
    if (typing && mounted) _focus.requestFocus();
  }

  Widget _controls(L l) {
    final rows = _panel.rows;
    final voice = _voice;
    final String label;
    final String icon;
    if (voice != null || _full) {
      (label, icon) = (l.actionStow, 'arrow_upward');
    } else if (_tray) {
      (label, icon) = _hasContent ? (l.actionStow, 'arrow_upward') : ('', 'mic');
    } else if (rows.isNotEmpty) {
      final action = actionOf(l, rows[_shownSelected.clamp(0, rows.length - 1)]);
      (label, icon) = (action.label, action.icon);
    } else {
      (label, icon) = _hasContent ? (l.actionStow, 'arrow_upward') : ('', 'mic');
    }

    // знаки # @ / уступают место подписи кнопки, когда ряд не вмещает всё
    final scaler = MediaQuery.textScalerOf(context);
    final labelWidth = label.isEmpty
        ? 0.0
        : (TextPainter(
            text: TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            textScaler: scaler,
            textDirection: TextDirection.ltr,
          )..layout()).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final glyphsFit = constraints.maxWidth - 44 - 48 - (labelWidth + 58) >= 3 * 34;
        return Row(
          children: [
            _AddButton(open: _tray, tooltip: l.composerAttach, onTap: _toggleTray),
            if (voice != null)
              Expanded(
                child: _Recording(session: voice, cancelTooltip: l.voiceCancel, onCancel: () => _stopVoice(keep: false)),
              )
            else ...[
              // знаки раздвигаются за 0,4 с и проявляются за 0,2 с
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Motion.emphasized,
                child: AnimatedOpacity(
                  opacity: _active && glyphsFit ? 1 : 0,
                  duration: Motion.short,
                  child: _active && glyphsFit
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // папку «только закинуть» не выбирает: знака «@» нет
                            for (final glyph in ['#', if (!widget.writeOnly) '@', '/']) _GlyphButton(glyph: glyph, onTap: () => _insertGlyph(glyph)),
                          ],
                        )
                      : const SizedBox(height: 44),
                ),
              ),
            ],
            if (voice != null)
              _SendButton(label: label, icon: icon, tooltip: label, busy: _sending, onTap: _act)
            else
              // на узком экране сжимается подпись кнопки, а не ряд
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: _full ? l.fullCollapse : l.fullExpand,
                      onPressed: () => _setFull(!_full),
                      style: IconButton.styleFrom(fixedSize: const Size.square(44), foregroundColor: Tokens.onSurfaceVariant),
                      icon: Icon(symbolIcon(_full ? 'close_fullscreen' : 'open_in_full'), size: 20),
                    ),
                    Flexible(
                      child: _SendButton(label: label, icon: icon, tooltip: label.isEmpty ? l.voiceRecord : label, busy: _sending, onTap: _act),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Лист выбора папки снизу.
class FolderPickerSheet extends StatelessWidget {
  const FolderPickerSheet({super.key, required this.title, required this.folders, this.allowNone = false, this.noneLabel, this.onNew});

  /// Ответ «Без папки»: null значит, что лист закрыли, ничего не выбрав.
  static const none = FolderCard(id: '', name: '', icon: 'inbox', shape: 'squircle', count: 0, covers: [], recentTitles: [], createdByAi: false);

  final String title;
  final List<FolderCard> folders;

  /// Первой строкой «Без папки» ([noneLabel]): вынуть заметку из папки. Выбор — [none].
  final bool allowNone;
  final String? noneLabel;

  /// «Новая папка» внизу: заводит папку и сразу выбирает её.
  final Future<FolderCard?> Function()? onNew;

  @override
  Widget build(BuildContext context) {
    return SheetOptionsBody(
      title: title,
      children: [
        if (allowNone) folderOption(icon: 'inbox', shape: 'squircle', name: noneLabel ?? '', onTap: () => Navigator.pop(context, none)),
        // деревом: вложенная сразу под родителем, путь родителей мелко под именем
        for (final folder in inTreeOrder(folders))
          folderOption(icon: folder.icon, shape: folder.shape, name: folder.name, path: folder.parentsLabel, onTap: () => Navigator.pop(context, folder)),
        if (onNew != null)
          folderOption(
            icon: 'create_new_folder',
            shape: 'squircle',
            name: L.of(context).folderPickNew,
            onTap: () async {
              final created = await onNew!();
              if (created != null && context.mounted) Navigator.pop(context, created);
            },
          ),
      ],
    );
  }
}

/// Строка выбора папки блоком, как в меню заметки: значок в форме папки, имя и, у вложенной,
/// путь родителей под ним («Дом / Ремонт»).
SheetOption folderOption({required String icon, required String shape, required String name, String? path, required VoidCallback onTap}) => SheetOption(
  title: name,
  subtitle: path,
  leading: ShapeBadge(
    shape: BadgeShape.values.asNameMap()[shape] ?? BadgeShape.squircle,
    size: 40,
    color: Tokens.graphite,
    child: Icon(symbolIcon(icon), size: 20, color: Tokens.onSurface),
  ),
  onTap: onTap,
);

/// Чип над строкой: тег, папка или напоминание, крестик снимает.
/// Подсказка над строкой: значок, текст в несколько строк и крестик, который всегда на виду.
class _LanguageHint extends StatelessWidget {
  const _LanguageHint({required this.text, required this.hideTooltip, required this.onHide});

  final String text;
  final String hideTooltip;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('language-hint'),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 6),
      child: Row(
        children: [
          Icon(symbolIcon('translate'), size: 18, color: Tokens.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Tokens.onSurfaceVariant, height: 1.3))),
          IconButton(
            tooltip: hideTooltip,
            onPressed: onHide,
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            color: Tokens.muted,
            icon: Icon(symbolIcon('close')),
          ),
        ],
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  const _LineChip({super.key, required this.leading, required this.label, required this.removeTooltip, required this.onRemove});

  final Widget leading;
  final String label;
  final String removeTooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _Pop(
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(17)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurface),
            ),
            IconButton(
              tooltip: removeTooltip,
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: Tokens.muted,
              icon: Icon(symbolIcon('close')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Куда ляжет текст из редактора: догадка строки, касание выбирает папку.
class _DestChip extends StatelessWidget {
  const _DestChip({super.key, required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RiseIn(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
          decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(17)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbolIcon(icon), size: 18, color: Tokens.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: Tokens.onSurface),
              ),
              Icon(symbolIcon('expand_more'), size: 18, color: Tokens.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoChip extends StatelessWidget {
  const _AutoChip({super.key, required this.label, required this.tooltip, required this.onTap});

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pop(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Tokens.outline, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(symbolIcon('add'), size: 16, color: Tokens.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14, color: Tokens.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({super.key, required this.leading, required this.label, required this.hint, required this.onTap});

  final Widget leading;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return RiseIn(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.fromLTRB(4, 0, 14, 0),
          decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 8),
              Text(
                label,
                style: text.labelMedium!.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.onSurface),
              ),
              const SizedBox(width: 6),
              Text(hint, style: text.labelSmall!.copyWith(fontSize: 12, color: Tokens.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Вложение в строке: картинка или значок вида, сверху крутится загрузка, потом галочка.
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({super.key, required this.attached, required this.tooltip, required this.onTap});

  final _Attached attached;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = attached.file;
    final Widget preview;
    if (attached.thumb != null) {
      preview = Image.memory(attached.thumb!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (file != null && file.mime.startsWith('image/')) {
      preview = Image.file(
        File(file.path),
        fit: BoxFit.cover,
        cacheWidth: (60 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => ColoredBox(color: Tokens.graphite),
      );
    } else {
      final icon = switch (attached.mime.split('/').first) {
        'video' => 'play_arrow',
        'audio' => 'graphic_eq',
        'text' => 'notes',
        _ => 'description',
      };
      final extension = file == null ? '' : p.extension(file.path).replaceFirst('.', '').toUpperCase();
      preview = ColoredBox(
        color: Tokens.graphite,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(symbolIcon(icon, filled: true), size: 22, color: Tokens.onSurface),
            if (extension.isNotEmpty && extension.length <= 5)
              Text(extension, style: Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 10, color: Tokens.onSurfaceVariant)),
          ],
        ),
      );
    }
    return _Pop(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(Radii.photo), child: preview),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    // загрузилось — галочка выпрыгивает с поворотом
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      reverseDuration: Duration.zero,
                      switchInCurve: Motion.spatial,
                      transitionBuilder: popTransition,
                      child: file == null
                          ? SizedBox.square(
                              key: const ValueKey('loading'),
                              dimension: 13,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Tokens.onAccent),
                            )
                          : Icon(symbolIcon('check'), key: const ValueKey('done'), size: 16, color: Tokens.onAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Чип и вложение появляются с пружинкой, а не возникают.
class _Pop extends StatefulWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  State<_Pop> createState() => _PopState();
}

// как att-in в макете: из 50% и прозрачности, пружинка 0,4 с; двигается готовый слой
class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
  late final Animation<double> _value = CurvedAnimation(parent: _controller, curve: Motion.spatial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _value.drive(const UnitClamp()),
      child: ScaleTransition(scale: _value.drive(Tween(begin: 0.5, end: 1.0)), child: widget.child),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.open, required this.tooltip, required this.onTap});

  final bool open;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: open ? Tokens.accent : Tokens.graphite, shape: BoxShape.circle),
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 400),
            curve: Motion.spatial,
            child: Icon(symbolIcon('add'), color: open ? Tokens.onAccent : Tokens.onSurface),
          ),
        ),
      ),
    );
  }
}

class _GlyphButton extends StatelessWidget {
  const _GlyphButton({required this.glyph, required this.onTap});

  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: glyph,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: SizedBox(
          width: 34,
          height: 44,
          child: Center(
            child: Text(
              glyph,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: 20, fontWeight: FontWeight.w500, color: Tokens.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _Recording extends StatelessWidget {
  const _Recording({required this.session, required this.cancelTooltip, required this.onCancel});

  final VoiceSession session;
  final String cancelTooltip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final seconds = session.elapsed.inSeconds;
    final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton(
          tooltip: cancelTooltip,
          onPressed: onCancel,
          icon: Icon(symbolIcon('close'), color: Tokens.onSurfaceVariant),
        ),
        const _Blink(),
        const SizedBox(width: 10),
        SizedBox(
          width: 46,
          child: Text(
            time,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(fontFamily: 'Unbounded', fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        Expanded(child: VoiceWave(levels: session.levels)),
      ],
    );
  }
}

class _Blink extends StatefulWidget {
  const _Blink();

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.2).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: Tokens.accent, shape: BoxShape.circle),
      ),
    );
  }
}

/// Кнопка строки: пустая — микрофон, иначе белая пилюля с тем, что она сделает.
class _SendButton extends StatefulWidget {
  const _SendButton({required this.label, required this.icon, required this.tooltip, required this.busy, required this.onTap});

  final String label;
  final String icon;
  final String tooltip;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  // подпись остаётся на месте, пока тает и сжимается, как в макете
  String _shown = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = widget.label;
    final open = label.isNotEmpty;
    if (open) _shown = label;
    const spring = Duration(milliseconds: 420);
    return Tooltip(
      message: widget.tooltip,
      child: Pressable(
        pressedScale: 0.9,
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedContainer(
          duration: spring,
          curve: Motion.spatial,
          height: 48,
          constraints: const BoxConstraints(minWidth: 48, maxWidth: 180),
          padding: EdgeInsets.only(left: open ? 16 : 12, right: 12),
          decoration: BoxDecoration(color: Tokens.accent, borderRadius: BorderRadius.circular(24)),
          child: AnimatedSize(
            duration: spring,
            curve: Motion.spatial,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ClipRect(
                    // ширина подписи пружинит; перелёт ниже нуля обрезается, иначе раскладка падает
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: open ? 1 : 0),
                      duration: spring,
                      curve: Motion.spatial,
                      builder: (context, width, child) => Align(alignment: Alignment.centerLeft, widthFactor: width.clamp(0.0, 1.5), child: child),
                      child: AnimatedOpacity(
                        opacity: open ? 1 : 0,
                        duration: Motion.short,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            _shown,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: Tokens.onAccent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // новый значок выпрыгивает, старый исчезает сразу
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  reverseDuration: Duration.zero,
                  switchInCurve: Motion.spatial,
                  transitionBuilder: popTransition,
                  child: Icon(
                    symbolIcon(widget.icon, filled: widget.icon == 'mic'),
                    key: ValueKey(widget.icon),
                    size: 24,
                    color: Tokens.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
