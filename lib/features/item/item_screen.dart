import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, XFile;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../base/base_file_screen.dart';
import '../canvas/canvas_file_screen.dart';
import '../drawing/drawing_screen.dart';
import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/file_picture.dart';
import '../../core/widgets/hint_banner.dart';
import '../../core/haptics.dart';
import '../../core/user_first.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/windowed_text_field.dart';
import '../../core/widgets/undo_snack.dart';
import '../../core/widgets/voice_player.dart';
import '../../data/db/database.dart';
import '../../core/clipboard/paste_router.dart';
import '../../core/platform.dart' show isWeb;
import '../../data/providers.dart';
import '../../domain/hints.dart' show Tip;
import '../../domain/place_cue.dart' show KnownPlace, parsePlaceCue;
import '../../domain/reminder_parser.dart' show parseReminder, reminderPhraseOf;
import '../../domain/text_diff.dart' show editedRange;
import '../../data/repositories/folders_repository.dart';
import '../../data/repositories/items_repository.dart';
import '../../domain/item_kind.dart';
import '../../domain/item_title.dart';
import '../../domain/models.dart';
import '../../domain/note_blocks.dart';
import '../../domain/note_links.dart';
import '../../domain/shopping.dart';
import '../../domain/vault_note.dart' show unpackVaultProperties;
import '../../l10n/app_localizations.dart';
import '../../services/capture_service.dart' show CaptureInput, PickedFile;
import '../composer/line_dock.dart';
import '../composer/markdown_bar.dart';
import '../composer/markdown_edit.dart';
import '../composer/math_edit.dart';
import '../composer/panel_text.dart';
import '../composer/smart_punctuation.dart';
import '../composer/wiki_link_edit.dart';
import '../composer/wiki_suggestions.dart';
import '../places/place_kinds.dart';
import '../places/places_screen.dart';
import '../places/reminder_permissions.dart';
import '../composer/picked_files.dart';
import '../folder/folder_sheets.dart';
import '../tags/tag_picker.dart';
import '../tags/tag_search.dart';
import '../reader/highlights_block.dart';
import '../reader/reader_screen.dart';
import 'copying_bar.dart';
import 'facts_block.dart';
import 'history_screen.dart';
import 'math_view.dart';
import 'note_place_sheet.dart';
import 'edit_toggle.dart';
import 'item_actions.dart' show changeItemDate, folderPath, toggleNoticed, togglePinned;
import 'page_card.dart';
import 'item_media.dart';
import 'pdf_panel.dart';
import 'markdown_controller.dart';
import 'note_body.dart';
import 'photo_viewer.dart';
import 'properties_block.dart';
import 'link_sheet.dart';
import 'related_block.dart';
import '../workspace/workspace_model.dart' show WsTab;
import '../workspace/workspace_shell.dart' show WorkspaceScope;

/// Страница вырастает из нажатой карточки и складывается в неё (переход темы);
/// открытая уведомлением или ссылкой — въезжает справа.
Route<void> itemRoute(String id) => MaterialPageRoute(builder: (_) => ItemScreen(id: id));

/// Открыть заметку. На компьютере — своей вкладкой рабочего пространства: экран поверх
/// вкладки был бы тупиком, кнопки «назад» там нет. На телефоне — экраном.
Future<void> openItem(BuildContext context, String id) async {
  final workspace = WorkspaceScope.maybeOf(context);
  if (workspace != null) return workspace.open(WsTab.item(id));
  await Navigator.of(context).push(itemRoute(id));
}

/// То же, что [openItem], но куда открывать, запоминается сейчас: открыть можно и после
/// ожидания, когда спросивший экран уже закрылся.
void Function(String id) itemOpener(BuildContext context) {
  final workspace = WorkspaceScope.maybeOf(context);
  final navigator = Navigator.of(context);
  return (id) => workspace != null ? workspace.open(WsTab.item(id)) : navigator.push(itemRoute(id)).ignore();
}

/// Пауза в наборе, после которой правка сохраняется сама.
const _autosaveDelay = Duration(milliseconds: 700);

/// Высота плавающей панели внизу и её отступ от края.
const _dockHeight = 72.0;
const _dockGap = 16.0;
// полоса разметки над панелью в правке
const _markdownStrip = 52.0;
// панель правки: полоса разметки, щель и пилюля «фото, отменить, вернуть» с «Готово»
const _editDockHeight = _markdownStrip + 8 + 64.0;
// подсказка «[[» не выше четырёх строк: текст вокруг курсора остаётся виден
const _wikiMax = 232.0;

/// Пробелы и переносы в конце текста: «Дописать» ставит курсор с новой строки,
/// а пустая строка в конце сохраняться не должна.
final _trailingSpace = RegExp(r'\s+$');

enum _MenuAction { pin, notice, copy, date, place, property, history, delete }

/// Вещь целиком, по образцу поста Togetherly: шапка с пилюлей папки, заголовок,
/// теги и напоминание отдельными блоками, текст своей карточкой, внизу плавающая
/// панель действий и «Дописать». Карандаш или касание по тексту открывают правку
/// на месте, тогда панель становится панелью разметки.
class ItemScreen extends ConsumerStatefulWidget {
  const ItemScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends ConsumerState<ItemScreen> {
  final _title = TextEditingController();
  // весь текст заметки; живое поле правки держит из него кусок у курсора — [_bodyWindow].
  // То, что смотрит только на место у курсора (подсказка «[[», формула, полоса разметки) и
  // считается на каждую букву, берёт кусок: на длинной заметке это в разы дешевле
  final _body = MarkdownController();
  final _bodyWindow = MarkdownController();
  final _bodyFocus = FocusNode();
  // «Отменить» и «Вернуть» в правке: и набранное, и кнопки разметки
  final _undo = UndoHistoryController();
  bool _editing = false;

  /// Для какой ссылки заметки превью уже просили: не просить на каждой перестройке экрана.
  String? _previewAsked;
  Timer? _autosave;
  String? _savedTitle;
  String? _savedBody;

  /// Какой снимок стоит крупно, когда их несколько.
  int _cover = 0;

  // берутся в initState: сохранять приходится и в dispose, когда ref уже нельзя трогать
  late final ItemsRepository _items;
  late final DateTime Function() _clock;
  late final int Function() _workEnd;

  String get _id => widget.id;

  @override
  void initState() {
    super.initState();
    _items = ref.read(itemsRepositoryProvider);
    _clock = ref.read(clockProvider);
    _workEnd = ref.read(workEndProvider);
    // свои места заранее: правка узнаёт «у Саши», даже если поток мест ещё не пришёл
    ref.read(placesRepositoryProvider).all().then((places) {
      if (mounted) _known = _knownOf(places);
    }).ignore();
    _title.addListener(_changed);
    _body.addListener(_changed);
    _bodyWindow.addListener(_watchWiki);
    _bodyWindow.addListener(_measureCaret);
    _scroll.addListener(_measureCaret);
    _bodyFocus.addListener(_measureCaret);
    // картинка из буфера (Ctrl+V) встаёт в эту заметку: её открыли — с ней и работают
    _paste = ref.read(pasteRouterProvider);
    _claimPaste();
    _bodyFocus.addListener(() {
      if (!_bodyFocus.hasFocus) return;
      _claimPaste();
      // есть ли картинка в буфере Android: меню «Вставить» строится сразу, ждать ответа не может
      ref.read(clipboardImagesProvider).refresh().ignore();
    });
    HardwareKeyboard.instance.addHandler(_onKey);
    // открыл — значит посмотрел: очередь «посмотреть потом» и сводка недели больше о ней не напомнят
    _items.markOpened(widget.id, _clock()).ignore();
  }

  @override
  void dispose() {
    _paste.release(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _autosave?.cancel();
    // ушли посреди правки — набранное не теряется
    if (_editing) _save();
    _title.dispose();
    _body.dispose();
    _bodyWindow.dispose();
    _bodyFocus.dispose();
    _undo.dispose();
    _scroll.dispose();
    _caret.dispose();
    super.dispose();
  }

  /// Правка на месте. Текст правится целиком: первая строка в нём остаётся. Заголовок из неё
  /// поле не показывает, поле — для своего. С `append` курсор встаёт с новой строки в конце.
  void _startEditing(Item item, {bool append = false}) {
    if (_editing) return;
    final body = item.body;
    _savedTitle = item.title;
    _savedBody = body.replaceFirst(_trailingSpace, '');
    _title.text = titleIsFirstLine(body, item.title) ? '' : item.title;
    _body.text = append && body.trim().isNotEmpty && !body.endsWith('\n') ? '$body\n' : body;
    _body.selection = TextSelection.collapsed(offset: _body.text.length);
    // кусок для живого поля — до показа: поле, заполняя его само, будило бы слушателей посреди построения
    _bodyWindow.value = WindowedTextField.windowFor(_body.value);
    if (ref.read(placesProvider).value case final places?) _known = _knownOf(places);
    _checkPhrases();
    _timeTouched = false;
    _placeTouched = false;
    setState(() => _editing = true);
    _bodyFocus.requestFocus();
  }

  // время и место в тексте, какими их видели на прошлом нажатии
  String? _seenPhrase;
  String? _seenPlace;

  /// Время или место в тексте трогали с прошлого сохранения: стёр «8» и набрал заново — тоже
  /// трогали, хотя текст вышел прежним. Тогда напоминание встаёт по тексту. Не трогали — правка
  /// рядом переставленное руками не сбивает.
  bool _timeTouched = false;
  bool _placeTouched = false;

  /// Свои места: «буду у Саши» узнаёт «Сашу». Берутся при входе в правку — сохранять
  /// приходится и в dispose, когда ref уже нельзя трогать.
  List<KnownPlace> _known = const [];

  List<KnownPlace> _knownOf(List<Place> places) => [for (final place in places) (id: place.id, name: place.name, kind: place.kind, label: place.label)];

  // разобранный на блоки текст: экран перестраивается и без правки текста (тег, папка, превью)
  String? _blocksText;
  List<NoteBlock> _blocks = const [];

  List<NoteBlock> _blocksOf(String body) {
    if (body != _blocksText) {
      _blocksText = body;
      _blocks = parseNoteBlocks(body);
    }
    return _blocks;
  }

  // текст на прошлой правке и где в нём стояли время и место на прошлой проверке
  String _lastText = '';
  List<(int, int)> _timeSpans = const [];
  (int, int)? _placeSpan;

  // текст правили после прошлой проверки времени и места
  var _phrasesStale = false;

  void _changed() {
    if (!_editing) return;
    // буква — человек занят: фон и пересчёты ждут (UserFirst)
    userFirst.touch();
    // время и место разбираются при сохранении, а не на букву и не на короткой паузе: разбор на
    // телефоне — десятки миллисекунд, и он лагал посреди набора (тестировщики 22 и 23.11).
    // Стёр «8» и набрал заново до сохранения — фраза та же, но её трогали: это видно по месту
    // правки, без разбора
    final text = '${_title.text}\n${_body.text}';
    final edit = editedRange(_lastText, text);
    if (_timeSpans.any(edit.touches)) _timeTouched = true;
    if (_placeSpan case final span? when edit.touches(span)) _placeTouched = true;
    _timeSpans = [for (final span in _timeSpans) edit.shift(span)];
    _placeSpan = _placeSpan == null ? null : edit.shift(_placeSpan!);
    _lastText = text;
    _phrasesStale = true;
    _restartAutosave();
  }

  void _restartAutosave() {
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, () => _save(pause: true));
  }

  // разбор времени и места отложен до конца набора
  var _phrasesWaiting = false;

  /// Когда человек перестанет печатать — разобрать время и место и сохранить напоминание.
  void _phrasesWhenCalm() {
    if (_phrasesWaiting) return;
    _phrasesWaiting = true;
    userFirst.calm().then((_) {
      _phrasesWaiting = false;
      if (mounted && _editing) _save(pause: true);
    }).ignore();
  }

  /// Фраза времени или места сменилась с прошлой проверки — их трогали.
  void _checkPhrases() {
    final text = '${_title.text}\n${_body.text}';
    _lastText = text;
    _phrasesStale = false;
    final found = parseReminder(text, _clock(), workEnd: _workEnd());
    final phrase = found == null ? null : reminderPhraseOf(text, found);
    if (phrase != _seenPhrase) _timeTouched = true;
    _seenPhrase = phrase;
    _timeSpans = found?.parts ?? const [];
    final cue = parsePlaceCue(text, places: _known);
    final place = cue == null ? null : '${cue.kind.name}|${cue.placeId}|${text.substring(cue.start, cue.end).toLowerCase()}';
    if (place != _seenPlace) _placeTouched = true;
    _seenPlace = place;
    _placeSpan = cue == null ? null : (cue.start, cue.end);
  }

  /// [pause] — сохранение в паузе набора: текст пишется сразу, а время и место (разбор всего
  /// текста, на телефоне десятки миллисекунд в потоке клавиатуры) — когда человек перестал
  /// печатать. Пауза между словами больше 0,7 с — обычное дело, и разбор на ней лагал
  /// (тестировщик 23.11). Выход из правки сохраняет всё сразу.
  Future<void> _save({bool pause = false}) async {
    if (pause && userFirst.busy && (_phrasesStale || _timeTouched || _placeTouched)) {
      _phrasesWhenCalm();
      await _saveText();
      return;
    }
    if (_phrasesStale) _checkPhrases();
    final body = _body.text.replaceFirst(_trailingSpace, '');
    final typed = _title.text.trim();
    // заголовок стёрли — берётся из текста, как при сохранении из строки
    final title = typed.isNotEmpty ? typed : titleFor(body);
    final timeTouched = _timeTouched;
    final placeTouched = _placeTouched;
    _timeTouched = false;
    _placeTouched = false;
    final same = title == _savedTitle && body == _savedBody;
    if (same && !timeTouched && !placeTouched) return;
    final text = '$title\n$body';
    final now = _clock();
    // «здесь» требует точки с телефона: его ставит только строка и лист «Напомнить»
    final cue = placeTouched ? parsePlaceCue(text, places: _known) : null;
    final place = cue?.kind == PlaceReminderKind.point ? null : cue;
    final found = timeTouched || place != null ? parseReminder(text, now, workEnd: _workEnd()) : null;
    // «завтра буду проходить мимо магазина»: день без часа рядом с местом — день места, а не звонок в 9 утра
    final placeDay = place != null && found != null && !found.hasTime ? DateTime(found.at.year, found.at.month, found.at.day) : null;
    if (!same) {
      _savedTitle = title;
      _savedBody = body;
      await _items.setTitleBody(_id, title: title, body: body, at: now);
    }
    if (place != null) {
      await _items.setPlaceReminder(_id, PlaceReminder(place.kind, ref: place.placeId, name: place.placeName, day: placeDay));
      if (placeDay != null) await _items.setReminder(_id, null);
    }
    // стёрли время или место — напоминание остаётся, его снимает галочка
    if (timeTouched && placeDay == null && found != null) await _items.setReminder(_id, found.at);
  }

  /// Только текст и заголовок, без времени и места.
  Future<void> _saveText() async {
    final body = _body.text.replaceFirst(_trailingSpace, '');
    final typed = _title.text.trim();
    final title = typed.isNotEmpty ? typed : titleFor(body);
    if (title == _savedTitle && body == _savedBody) return;
    _savedTitle = title;
    _savedBody = body;
    await _items.setTitleBody(_id, title: title, body: body, at: _clock());
  }

  Future<void> _finish() async {
    _autosave?.cancel();
    await _save();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _markdown(MarkdownAction action) {
    _body.value = applyMarkdown(_body.value, action);
    _bodyFocus.requestFocus();
  }

  /// Заметки для подсказки `[[…`: читаются один раз, когда курсор впервые встал в скобки.
  List<LinkTarget>? _linkTargets;

  void _watchWiki() {
    if (_linkTargets != null || wikiQueryOf(_bodyWindow.value) == null) return;
    _linkTargets = const [];
    _items.linkTargets().then((targets) {
      if (mounted) setState(() => _linkTargets = targets);
    }).ignore();
  }

  void _pickWiki(LinkTarget target) {
    _body.value = completeWikiLink(_body.value, target.title);
    _bodyFocus.requestFocus();
  }

  /// «Создать заметку «…»» из подсказки: заметка заводится в той же папке, ссылка закрывается.
  Future<void> _createWiki(String title) async {
    final id = await _createNote(title);
    if (!mounted) return;
    _linkTargets = [...?_linkTargets, (id: id, title: title, text: title, at: _clock(), kind: ItemKind.note)];
    _body.value = completeWikiLink(_body.value, title);
    _bodyFocus.requestFocus();
  }

  /// Новая заметка по ссылке: только заголовок, рядом с этой, без поиска времени и места в нём.
  Future<String> _createNote(String title) async {
    final folderId = (await _items.watchItem(_id).first)?.item.folderId;
    return ref.read(captureServiceProvider).capture(CaptureInput(text: title, forcedFolderId: folderId, detectReminder: false, detectPlace: false, here: false));
  }

  // где строка с курсором — в координатах [_stackKey]: подсказка «[[» встаёт над ней
  final _stackKey = GlobalKey();
  final _scroll = ScrollController();
  final _caret = ValueNotifier<Rect?>(null);

  /// Формула под курсором правки, если в ней уже что-то набрано.
  MathAround? _mathAtCaret() {
    // формула не делится между кусками окна: смотреть хватит на кусок у курсора
    final value = _bodyWindow.value;
    if (!value.selection.isValid || !value.selection.isCollapsed) return null;
    final formula = mathAround(value.text, value.selection.baseOffset);
    return formula == null || formula.tex.trim().isEmpty ? null : formula;
  }

  void _measureCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // меряем, только пока подсказка или просмотр формулы нужны: после правки поля уже нет
      if (!_editing || !_bodyFocus.hasFocus || (wikiQueryOf(_bodyWindow.value) == null && _mathAtCaret() == null)) {
        _caret.value = null;
        return;
      }
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final editable = _bodyFocus.context?.findAncestorStateOfType<EditableTextState>()?.renderEditable;
      // курсор живого поля — его же отсчётом
      final selection = _bodyWindow.selection;
      if (stack == null || editable == null || !editable.attached || !selection.isValid) {
        _caret.value = null;
        return;
      }
      final local = editable.getLocalRectForCaret(selection.extent);
      final topLeft = stack.globalToLocal(editable.localToGlobal(local.topLeft));
      _caret.value = topLeft & local.size;
    });
  }

  /// «купить молоко, хлеб и яйца» — «Купить:» и пункты галочками; «Отменить» возвращает как было.
  Future<void> _toChecklist(Item item, String checklist) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final (title, body) = (item.title, item.body);
    await _items.setTitleBody(_id, title: titleFor(checklist), body: checklist, at: _clock());
    showUndo(messenger, message: l.toChecklistDone, label: l.undo, overDock: true, onUndo: () => _items.setTitleBody(_id, title: title, body: body, at: _clock()));
  }

  Future<void> _toggle(Item item, int index) async {
    final body = toggleCheckLine(item.body, index);
    if (body != item.body) await _items.setBody(_id, body, _clock());
  }

  Future<void> _move(Item item, List<FolderCard> folders) async {
    final l = L.of(context);
    final target = await showOptionsSheetWith<FolderCard>(
      context,
      (sheet) => FolderPickerSheet(
        title: l.folderPickTitle,
        folders: [for (final folder in folders) if (folder.id != item.folderId) folder],
        // угадыватель ошибся папкой — заметку можно вынуть совсем, он это запомнит
        allowNone: item.folderId != null,
        noneLabel: l.folderNone,
        onNew: () => askNewFolder(sheet, ref),
      ),
    );
    if (target == null || !mounted) return;
    final from = item.folderId;
    final to = target == FolderPickerSheet.none ? null : target.id;
    await _items.moveToFolder(_id, to, _clock());
    if (!mounted) return;
    showUndo(ScaffoldMessenger.of(context), message: l.itemMoved(to == null ? l.folderNone : target.name), label: l.undo, onUndo: () => _items.moveToFolder(_id, from, _clock()));
  }

  Future<void> _pickReminder(DateTime? current) async {
    final now = _clock();
    final start = current ?? DateTime(now.year, now.month, now.day + 1, 9);
    final day = await showDatePicker(context: context, initialDate: start.isBefore(now) ? now : start, firstDate: now, lastDate: DateTime(now.year + 5));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
    if (time == null) return;
    await _items.setReminder(_id, DateTime(day.year, day.month, day.day, time.hour, time.minute));
    await askNotifications(ref);
  }

  /// Дата заметки: «сейчас» или свой день и время. Будущего у записанного нет.
  Future<void> _changeDate(Item item) => changeItemDate(context, ref, id: _id, created: item.createdAt);

  /// Свойства из файла: правка ложится сразу, удалённое можно вернуть.
  Future<void> _setProperties(Map<String, Object?> before, Map<String, Object?> next) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _items.setProperties(_id, next, _clock());
    if (next.length < before.length) {
      showUndo(messenger, message: l.propertyRemoved, label: l.undo, overDock: true, onUndo: () => _items.setProperties(_id, before, _clock()));
    }
  }

  Future<void> _addProperty(Item item) async {
    final before = unpackVaultProperties(item.properties);
    final next = await editProperty(context, before);
    if (next != null && mounted) await _setProperties(before, next);
  }

  PlaceReminder? _placeOf(Item item) => placeReminderOf(item);

  /// «Напомнить»: по времени, здесь, у своего места или у любого места вида
  /// (виды — те, где мест больше одного). Мест нет — дом, работа, магазин и «Места».
  Future<void> _remindSheet() async {
    final l = L.of(context);
    final places = ref.read(placesProvider).value ?? await ref.read(placesRepositoryProvider).all();
    if (!mounted) return;
    // сколько мест у готового вида и у своего («Дача»): «у любого» — где их больше одного
    final counts = <PlaceKind, int>{};
    final labels = <String, int>{};
    for (final place in places) {
      if (place.label case final label?) {
        labels[label] = (labels[label] ?? 0) + 1;
      } else {
        counts[place.kind] = (counts[place.kind] ?? 0) + 1;
      }
    }
    final kinds = places.isEmpty
        ? const [PlaceKind.home, PlaceKind.work, PlaceKind.shop]
        : [for (final kind in PlaceKind.values) if ((counts[kind] ?? 0) > 1) kind];
    final groups = [for (final MapEntry(key: label, value: count) in labels.entries) if (count > 1) label];
    // «time», «places» или готовое напоминание по месту; смахнули лист — null
    final choice = await showOptionsSheet<Object>(
      context,
      title: l.itemRemind,
      options: [
        SheetChoice(value: 'time', title: l.itemRemindTime, icon: 'schedule'),
        SheetChoice(value: const PlaceReminder(PlaceReminderKind.point), title: l.placeRemindHere, icon: 'my_location'),
        for (final place in places)
          SheetChoice(value: PlaceReminder(PlaceReminderKind.place, ref: place.id, name: place.name), title: l.placeRemindAt(place.name), icon: place.icon ?? placeTypeIcon(typeOf(place))),
        for (final kind in kinds) SheetChoice(value: PlaceReminder(remindAtKind(kind)), title: remindPlaceLabel(l, remindAtKind(kind)), icon: placeKindIcon(kind)),
        for (final label in groups)
          SheetChoice(
            value: PlaceReminder(PlaceReminderKind.place, ref: placeTypeRef(label), name: label),
            title: l.placeRemindAt(label),
            icon: placeTypeIcon(typeOf(places.firstWhere((place) => place.label == label))),
          ),
        SheetChoice(value: 'places', title: l.placesTitle, icon: 'add_location_alt'),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'time':
        await _pickReminder(null);
      case 'places':
        await Navigator.of(context).push(placesRoute());
      case PlaceReminder place:
        await _setPlace(place);
    }
  }

  Future<void> _setPlace(PlaceReminder chosen) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (chosen.kind == PlaceReminderKind.point) {
      final fix = await ref.read(currentPlaceProvider)();
      if (fix == null) {
        showNote(messenger, l.placesNoFix);
        return;
      }
      await _items.setPlaceReminder(_id, PlaceReminder(PlaceReminderKind.point, latitude: fix.latitude, longitude: fix.longitude, name: fix.name));
      await askPlaceReminder(ref, messenger, l, overDock: true);
      return;
    }
    await _items.setPlaceReminder(_id, chosen);
    await askNotifications(ref);
    // своё место есть всегда; у вида — есть ли хоть одно место этого вида
    final places = ref.read(placesProvider).value ?? await ref.read(placesRepositoryProvider).all();
    final wanted = placeKindOf(chosen.kind);
    // место отмечено — проверить «всегда»; не отмечено — ведём в «Места», там своя карточка разрешения
    if (wanted == null || places.any((place) => place.kind == wanted)) {
      await askPlaceReminder(ref, messenger, l, overDock: true);
      return;
    }
    showUndo(messenger, message: l.placesMissingKind, label: l.placesTitle, onUndo: () => navigator.push(placesRoute()), overDock: true);
  }

  Future<void> _placeMenu(PlaceReminder current) async {
    final l = L.of(context);
    final remove = await showOptionsSheet<bool>(
      context,
      options: [
        SheetChoice(value: false, title: l.itemPlaceChange, icon: 'edit_location_alt'),
        SheetChoice(value: true, title: l.itemReminderRemove, icon: 'location_off', danger: true),
      ],
    );
    if (remove == null || !mounted) return;
    if (remove) {
      await _items.setPlaceReminder(_id, null);
      if (mounted) showUndo(ScaffoldMessenger.of(context), message: l.reminderCleared, label: l.undo, onUndo: () => _items.setPlaceReminder(_id, current));
    } else {
      await _remindSheet();
    }
  }

  Future<void> _reminderMenu(DateTime current) async {
    final l = L.of(context);
    final remove = await showOptionsSheet<bool>(
      context,
      options: [
        SheetChoice(value: false, title: l.itemReminderChange, icon: 'edit_calendar'),
        SheetChoice(value: true, title: l.itemReminderRemove, icon: 'notifications_off', danger: true),
      ],
    );
    if (remove == null || !mounted) return;
    if (remove) {
      await _items.setReminder(_id, null);
      if (mounted) showUndo(ScaffoldMessenger.of(context), message: l.reminderCleared, label: l.undo, onUndo: () => _items.setReminder(_id, current));
    } else {
      await _pickReminder(current);
    }
  }

  Future<void> _addTag() async {
    final own = ref.read(itemProvider(_id)).value?.tags.keys.toSet() ?? const <String>{};
    final all = ref.read(allTagsProvider).value ?? const [];
    final name = await showTagPicker(context, tags: [for (final tag in all) if (!own.contains(tag.name)) tag], filesRoot: ref.read(filesRootProvider));
    if (name != null) await ref.read(tagsRepositoryProvider).link(_id, name);
  }

  /// «+ Связь»: найти заметку по словам и связать, с «Отменить».
  Future<void> _addLink() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final target = await pickLinkTarget(context, ref, exceptId: _id);
    if (target == null || !mounted) return;
    await _items.link(_id, target.id);
    showUndo(messenger, message: l.linkAdded(target.title), label: l.undo, onUndo: () => _items.unlink(_id, target.id), overDock: true);
  }

  /// Ингредиенты рецепта — отдельной заметкой-списком «Купить: …», с «Открыть» в плашке.
  Future<void> _shoppingList(Item item, List<String> ingredients) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final open = itemOpener(context);
    final text = '${l.shoppingFor(item.title)}\n${[for (final ingredient in ingredients) '- [ ] $ingredient'].join('\n')}';
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: text, detectReminder: false));
    showUndo(messenger, message: l.shoppingReady, label: l.actionOpen, onUndo: () => open(id), overDock: true);
  }

  /// Фото в правке встают в текст на место курсора строками `![[имя]]`, как в Obsidian.
  /// Имя своё и с датой: на него ссылается текст, а у галереи имена вроде «1000012345.jpg».
  Future<void> _addPhotos() async {
    final caret = _body.value;
    // клавиатура под системным окном выбора только мешает
    FocusScope.of(context).unfocus();
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      await _insertFiles(picked, caret);
    } catch (_) {
      if (mounted) showNote(ScaffoldMessenger.of(context), L.of(context).attachFailed);
    }
  }

  late final PasteRouter _paste;

  void _claimPaste() => _paste.claim(this, _pasted, shown: () => shownOnScreen(this));

  /// Вставка из буфера (Ctrl+V): картинка встаёт в текст там, где курсор. Заметку только
  /// смотрят — она переходит в правку, и картинка встаёт в конец текста.
  Future<void> _pasted(List<XFile> files) async {
    final full = ref.read(itemProvider(_id)).value;
    if (full == null || !mounted) return;
    if (!_editing) _startEditing(full.item, append: true);
    try {
      await _insertFiles(files, _body.value);
    } catch (_) {
      if (mounted) showNote(ScaffoldMessenger.of(context), L.of(context).attachFailed);
    }
  }

  /// Файлы во вложения заметки; картинки ещё и в текст строками на место [caret]. Остальные
  /// файлы (документ из проводника) видны в «Файлах» заметки.
  Future<void> _insertFiles(List<XFile> files, TextEditingValue caret) async {
    final taken = {
      for (final file in ref.read(itemProvider(_id)).value?.attachments ?? const <Attachment>[]) p.basename(file.path).replaceFirst(RegExp(r'^\d+_'), '').toLowerCase(),
    };
    final now = _clock();
    final attached = <PickedFile>[];
    final pictures = <String>[];
    for (final file in files) {
      final one = await pickedFromXFile(file);
      if (!showsAsImage(one.mime)) {
        attached.add(one);
        continue;
      }
      final extension = p.extension(one.path).replaceFirst('.', '').toLowerCase();
      final name = photoFileName(now, extension.isEmpty ? 'jpg' : extension, taken);
      taken.add(name.toLowerCase());
      attached.add(PickedFile(path: one.path, mime: one.mime, size: one.size, name: name));
      pictures.add(name);
    }
    await ref.read(captureServiceProvider).attach(_id, attached);
    if (!mounted) return;
    if (pictures.isNotEmpty) _body.value = insertImageLines(caret, pictures);
    _bodyFocus.requestFocus();
  }

  Future<void> _openLink(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    // [[Заметка]] в тексте: открыть заметку с этим заголовком
    if (url.startsWith(noteLinkScheme)) {
      final title = url.substring(noteLinkScheme.length);
      // связи из текста уже посчитаны для «Связано»: заметка находится сразу, без запроса
      final known = (ref.read(relatedProvider(_id)).value ?? const <LinkedNote>[])
          .where((linked) => linked.kind == LinkKind.text && linked.card.title.trim().toLowerCase() == title.trim().toLowerCase())
          .firstOrNull
          ?.card
          .id;
      final target = known ?? await _items.findByTitle(title);
      if (!mounted) return;
      if (target == _id) return;
      if (target == null) {
        // как в Obsidian: ссылка на то, чего ещё нет, заводит заметку
        final l = L.of(context);
        final open = itemOpener(context);
        showUndo(
          messenger,
          message: l.linkMissing(title),
          label: l.linkCreateAction,
          overDock: true,
          onUndo: () async {
            final id = await _createNote(title);
            if (mounted) open(id);
          },
        );
        return;
      }
      await openItem(context, target);
      return;
    }
    final message = L.of(context).linkOpenFailed;
    final uri = Uri.tryParse(url);
    final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened) showNote(messenger, message, overDock: true);
  }

  /// Текст вещи как есть, а если его нет — заголовок.
  String _plainText(Item item) => item.body.trim().isEmpty ? item.title : item.body;

  Future<void> _share(Item item, List<Attachment> attachments, Directory filesRoot) async {
    final box = context.findRenderObject() as RenderBox?;
    // share_plus 13 бросает ошибку на пустой список файлов и пустой текст: у заметки без вложений
    // «Поделиться» молча не делало ничего. Файл, которого уже нет на диске, тоже уронил бы всё
    final files = [
      for (final file in attachments)
        if (File(p.join(filesRoot.path, file.path)).existsSync()) XFile(p.join(filesRoot.path, file.path), mimeType: file.mime),
    ];
    final text = _plainText(item).trim();
    if (files.isEmpty && text.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
      text: text.isEmpty ? null : text,
      subject: item.title,
      files: files.isEmpty ? null : files,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _copy(Item item) async {
    await Clipboard.setData(ClipboardData(text: _plainText(item)));
    if (mounted) showNote(ScaffoldMessenger.of(context), L.of(context).itemCopied);
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _autosave?.cancel();
    _editing = false;
    Haptics.delete().ignore();
    await _items.softDelete(_id, _clock());
    // во вкладке сайта заметка — единственный экран: pop снимал его и оставлял белое поле,
    // вкладку закрывает она сама, увидев удаление; на телефоне экран уходит, как раньше
    if (mounted) Navigator.maybePop(context).ignore();
    showUndo(messenger, message: l.itemDeleted, label: l.undo, onUndo: () => _items.restore(_id));
  }

  Future<void> _menu(Item item) async {
    final l = L.of(context);
    final hasHistory = (ref.read(noteVersionsProvider(_id)).value ?? const []).isNotEmpty;
    final action = await showOptionsSheet<_MenuAction>(
      context,
      title: item.title,
      options: [
        SheetChoice(value: _MenuAction.pin, title: item.pinnedAt == null ? l.itemPin : l.itemUnpin, icon: 'keep'),
        SheetChoice(
          value: _MenuAction.notice,
          title: item.noticeAt == null ? l.noticePin : l.noticeUnpin,
          icon: item.noticeAt == null ? 'notifications_active' : 'notifications_off',
        ),
        SheetChoice(value: _MenuAction.copy, title: l.itemCopy, icon: 'content_copy'),
        SheetChoice(value: _MenuAction.date, title: l.itemDateChange, icon: 'calendar_today'),
        SheetChoice(value: _MenuAction.place, title: item.latitude == null ? l.itemPlaceAdd : l.itemPlaceTitle, icon: 'location_on'),
        SheetChoice(value: _MenuAction.property, title: l.propertyAdd, icon: 'list_alt'),
        if (hasHistory) SheetChoice(value: _MenuAction.history, title: l.historyTitle, icon: 'history'),
        SheetChoice(value: _MenuAction.delete, title: l.itemDelete, icon: 'delete', danger: true),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MenuAction.pin:
        await togglePinned(context, ref, id: _id, pinned: item.pinnedAt != null, overDock: false);
      case _MenuAction.notice:
        await toggleNoticed(context, ref, id: _id, noticed: item.noticeAt != null, overDock: false);
      case _MenuAction.copy:
        await _copy(item);
      case _MenuAction.date:
        await _changeDate(item);
      case _MenuAction.place:
        await editNotePlace(context, ref, item);
      case _MenuAction.property:
        await _addProperty(item);
      case _MenuAction.history:
        await _history();
      case _MenuAction.delete:
        await _delete();
    }
  }

  /// Путь папки заметки для строки на мониторе: от верхней папки до своей.
  List<(String?, String)> _deskPath(L l, FolderCard? folder, List<FolderCard> folders) => folderPath(l, folder?.id, folders);

  /// История правок. Вернули версию — плашка «Отменить» возвращает то, что было до неё:
  /// оно лежит в истории самым свежим снимком.
  Future<void> _history() async {
    if (_editing) await _finish();
    if (!mounted) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final restored = await Navigator.of(context).push(historyRoute(_id));
    if (restored != true) return;
    final history = ref.read(historyRepositoryProvider);
    showUndo(
      messenger,
      message: l.historyRestored,
      label: l.undo,
      onUndo: () async {
        final latest = await history.latest(_id);
        if (latest != null) await history.restore(latest, _clock());
      },
      overDock: true,
    );
  }

  /// Ctrl+E: просмотр ↔ правка. Из правки — сохранить и выйти, как «Готово».
  void _toggleEditing() {
    if (_editing) {
      _finish().ignore();
      return;
    }
    final item = ref.read(itemProvider(_id)).value?.item;
    if (item != null && item.deletedAt == null) _startEditing(item);
  }

  // телефон и планшет с клавиатурой: рабочего пространства с его сочетаниями там нет
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || event.physicalKey != PhysicalKeyboardKey.keyE) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed) || keyboard.isAltPressed || keyboard.isShiftPressed) return false;
    if (WorkspaceScope.maybeOf(context) != null || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    _toggleEditing();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    // монитор: сочетание «Правка и просмотр» (Ctrl+E) ведёт рабочее пространство
    ref.listen(editToggleProvider, (_, request) {
      if (request?.itemId == _id) _toggleEditing();
    });
    final full = ref.watch(itemProvider(_id)).value;
    final facts = ref.watch(itemFactsProvider(_id)).value ?? const <Fact>[];
    final highlights = ref.watch(highlightsProvider(_id)).value ?? const <Highlight>[];
    // история держится живой, пока заметка открыта: меню «⋮» решает по ней сразу
    ref.watch(noteVersionsProvider(_id));
    final folders = ref.watch(foldersProvider).value ?? const <FolderCard>[];
    final filesRoot = ref.watch(filesRootProvider);
    final now = _clock();
    if (full == null) return const Scaffold();
    final item = full.item;
    // холст, база и рисунок Obsidian — свои экраны; все пути открытия заметки ведут сюда же
    if (item.kind == ItemKind.canvas) return CanvasFileScreen(item: item);
    if (item.kind == ItemKind.base) return BaseFileScreen(item: item);
    if (item.kind == ItemKind.drawing) return DrawingScreen(item: item);
    final folder = folders.where((one) => one.id == item.folderId).firstOrNull;
    // картинка — только то, что умеем показать; макет Photoshop или TIFF — файл с карточкой
    final images = full.attachments.where((file) => showsAsImage(file.mime)).toList();
    // фото, вставленные в текст, стоят на своём месте в тексте, а не крупно над заголовком
    final attachmentPaths = [for (final file in full.attachments) file.path];
    final inline = {for (final name in embedNames(item.body)) ?embedPath(name, attachmentPaths)};
    final gallery = [for (final image in images) if (!inline.contains(image.path)) image];
    // у заметки с текстом фото без вставки идут после текста, как вставки в конце файла; у фото
    // без текста — крупно сверху, оно и есть заметка
    final writtenText = item.body.split('\n').where((line) => !embedLine.hasMatch(line)).join('\n').trim().isNotEmpty;
    final galleryBelow = writtenText && gallery.isNotEmpty;
    final url = item.url;
    // ссылка и ролик по адресу живут превью; свой ролик — файлом с обложкой и «Смотреть»
    final linkLike = url != null && (item.kind == ItemKind.link || item.kind == ItemKind.video);
    final videoLink = linkLike && item.kind == ItemKind.video;
    // у заметки превью ссылки грузится, когда её открыли: заметок со ссылками тысячи, и
    // качать превью всем разом после обновления — лишний трафик
    if (item.kind == ItemKind.note && url != null && item.previewAt == null && _previewAsked != url) {
      _previewAsked = url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(linkPreviewServiceProvider).retry([_id]).ignore();
      });
    }
    final videoFile = !linkLike && item.kind == ItemKind.video ? full.attachments.where((file) => file.mime.startsWith('video/')).firstOrNull : null;
    final voices = full.attachments.where((file) => file.mime.startsWith('audio/')).toList();
    // файлы строкой под текстом — кроме вставленных в текст: те стоят на своём месте
    final files = full.attachments.where((file) => !showsAsImage(file.mime) && !file.mime.startsWith('audio/') && file != videoFile && !inline.contains(file.path)).toList();
    // адрес уже стоит в превью: строкой в тексте он не повторяется
    final shownBody = linkLike ? item.body.split('\n').where((line) => line.trim() != url).join('\n') : item.body;
    // широкий экран (вкладка рабочего пространства): текст колонкой до 760 точек посередине, как в
    // макете, сверху тонкая строка с путём папки и действиями, низ окна отдан общей строке ввода
    final desk = WorkspaceScope.maybeOf(context) != null;
    final titleFromLine = titleIsFirstLine(shownBody, item.title);
    // блоки и список покупок — для чтения. В правке текст показывает поле, а экран перестраивается
    // после каждого автосохранения: разбор всей длинной заметки там был бы лишним тяжёлым кадром
    final blocks = _editing ? const <NoteBlock>[] : _blocksOf(shownBody);
    // «купить молоко, хлеб и яйца» можно одним касанием сделать галочками
    final checklist = !_editing && item.kind == ItemKind.note ? shoppingChecklist(item.body) : null;
    final properties = unpackVaultProperties(item.properties);
    // заголовок из первой строки над ней же не повторяется: заметка видна, как её написали.
    // На мониторе так же: 21.11 хозяин назвал крупную первую строку ошибкой — «это текст»
    final showTitle = _editing || linkLike || !titleFromLine;
    final source = url == null ? null : sourceName(Uri.tryParse(url)?.host ?? '');
    final duration = item.durationSeconds == null ? null : Duration(seconds: item.durationSeconds!);
    Future<void> openMain() => videoFile != null ? openLocalFile(context, p.join(filesRoot.path, videoFile.path), videoFile.mime) : _openLink(url!);
    // на мониторе заголовок документа крупнее, как в макете веба
    final titleStyle = desk
        ? text.headlineSmall!.copyWith(fontSize: 32, height: 1.15, letterSpacing: -0.6)
        : text.headlineSmall!.copyWith(fontSize: 25, height: 1.2, letterSpacing: -0.4);
    final bodyStyle = text.bodyLarge!.copyWith(fontSize: 16, height: 1.5, color: Tokens.onSurface);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final side = desk ? math.max(12.0, (MediaQuery.sizeOf(context).width - _deskColumn) / 2) : 12.0;
    final cover = gallery.isEmpty ? null : gallery[_cover.clamp(0, gallery.length - 1)];
    // картинка из текста по имени; касание открывает просмотр всех фото заметки на ней
    Widget inlineImage(String name) {
      final path = embedPath(name, attachmentPaths);
      final image = images.where((one) => one.path == path).firstOrNull;
      if (image == null) {
        // вставлен не рисунок: PDF — просмотром, как в Obsidian, другой файл — строкой файла
        final file = full.attachments.where((one) => one.path == path).firstOrNull;
        if (file == null) return MissingImage(name: name);
        if (isPdfFile(file.mime, file.path)) return PdfPanel(path: p.join(filesRoot.path, file.path), mime: file.mime);
        return FileTile(file: file, filesRoot: filesRoot);
      }
      return _PhotoCover(
        image: image,
        filesRoot: filesRoot,
        radius: Radii.tile,
        onOpen: () => PhotoViewer.open(context, [for (final one in images) p.join(filesRoot.path, one.path)], images.indexOf(image)),
      );
    }


    // в шапке вид вещи («заметка», «3 фото»), пока правка — что всё сохраняется; дата и место — строкой под заголовком
    final what = images.isNotEmpty ? l.itemPhotos(images.length) : kindLabel(l, item.kind);
    final subtitle = _editing ? l.itemAutosave : _capitalized(what);

    final Widget dock = AnimatedSwitcher(
        duration: Motion.medium,
        child: _editing
            ? Column(
                key: const ValueKey('edit-dock'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  // та же полоса разметки, что в строке на весь экран
                  Container(
                    height: _markdownStrip,
                    decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: BorderRadius.circular(_markdownStrip / 2)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    child: MarkdownBar(onAction: _markdown, field: _bodyWindow),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder(
                    valueListenable: _undo,
                    builder: (context, history, _) => _Dock(
                      height: 64,
                      buttons: [
                        _DockButton(icon: 'add_photo_alternate', tooltip: l.itemAddPhoto, onTap: _addPhotos),
                        _DockButton(icon: 'undo', tooltip: l.mdUndo, onTap: history.canUndo ? _undo.undo : null),
                        _DockButton(icon: 'redo', tooltip: l.mdRedo, onTap: history.canRedo ? _undo.redo : null),
                      ],
                      accentIcon: 'check',
                      accentLabel: l.itemEditDone,
                      onAccent: _finish,
                    ),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('view-dock'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // значки панели без подписей: один раз сказать, что они делают
                  if (!desk) const HintBanner(tip: Tip.noteBar, padding: EdgeInsets.only(bottom: 8)),
                  _Dock(
                height: _dockHeight,
                buttons: [
                  _DockButton(
                    icon: item.reminderAt != null || item.remindPlace != null ? 'alarm' : 'add_alarm',
                    tooltip: l.itemRemind,
                    active: item.reminderAt != null || item.remindPlace != null,
                    onTap: () => item.reminderAt != null
                        ? _reminderMenu(item.reminderAt!)
                        : item.remindPlace != null
                        ? _placeMenu(_placeOf(item)!)
                        : _remindSheet(),
                  ),
                  _DockButton(icon: 'tag', tooltip: l.tagAdd, onTap: _addTag),
                  // у ссылки главное — открыть, поэтому дописать мысль уходит в панель
                  if (linkLike)
                    _DockButton(icon: 'edit_note', tooltip: l.itemAppend, onTap: () => _startEditing(item, append: true))
                  else
                    _DockButton(icon: 'drive_file_move', tooltip: l.itemMove, onTap: () => _move(item, folders)),
                  // в браузере поделиться нечем: на компьютере он открывал бы почтовую программу
                  if (!isWeb) _DockButton(icon: 'share', tooltip: l.itemShare, onTap: () => _share(item, full.attachments, filesRoot)),
                ],
                accentIcon: videoLink || videoFile != null ? 'play_arrow' : (linkLike ? 'open_in_new' : 'add'),
                accentLabel: videoLink || videoFile != null ? l.itemWatch : (linkLike ? l.itemOpenLink : l.itemAppend),
                onAccent: linkLike || videoFile != null ? openMain : () => _startEditing(item, append: true),
              ),
                ],
              ),
    );

    return PopScope(
      // «назад» посреди правки сначала закрывает правку, сохранив текст
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      // коснулись заметки (вкладка рядом с холстом, второй экран) — вставка из буфера снова в неё
      child: Listener(
        onPointerDown: (_) => _claimPaste(),
        child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (desk)
                Padding(
                  padding: EdgeInsets.fromLTRB(side - 6, 8, side - 6, 4),
                  child: _DeskBar(
                    path: _deskPath(l, folder, folders),
                    onPath: (id) => WorkspaceScope.maybeOf(context)?.open(id == null ? const WsTab.inbox() : WsTab.folder(id)),
                    actions: [
                      if (!_editing) ...[
                        _DeskAction(
                          icon: item.reminderAt != null || item.remindPlace != null ? 'alarm' : 'add_alarm',
                          tooltip: l.itemRemind,
                          active: item.reminderAt != null || item.remindPlace != null,
                          onTap: () => item.reminderAt != null
                              ? _reminderMenu(item.reminderAt!)
                              : item.remindPlace != null
                              ? _placeMenu(_placeOf(item)!)
                              : _remindSheet(),
                        ),
                        _DeskAction(icon: 'tag', tooltip: l.tagAdd, onTap: _addTag),
                        if (linkLike)
                          _DeskAction(icon: 'edit_note', tooltip: l.itemAppend, onTap: () => _startEditing(item, append: true))
                        else
                          _DeskAction(icon: 'drive_file_move', tooltip: l.itemMove, onTap: () => _move(item, folders)),
                        if (!isWeb) _DeskAction(icon: 'share', tooltip: l.itemShare, onTap: () => _share(item, full.attachments, filesRoot)),
                        _DeskAction(icon: 'edit', tooltip: l.itemEdit, onTap: () => _startEditing(item)),
                      ],
                      _DeskAction(icon: 'more_vert', tooltip: l.itemMore, onTap: () => _menu(item)),
                    ],
                    // в правке главное действие — «Готово» на том же месте
                    accentIcon: _editing ? 'check' : (videoLink || videoFile != null ? 'play_arrow' : (linkLike ? 'open_in_new' : 'add')),
                    accentLabel: _editing ? l.itemEditDone : (videoLink || videoFile != null ? l.itemWatch : (linkLike ? l.itemOpenLink : l.itemAppend)),
                    onAccent: _editing ? _finish : (linkLike || videoFile != null ? openMain : () => _startEditing(item, append: true)),
                  ),
                )
              else
                _Header(
                  folder: folder,
                  folderName: folder?.name ?? l.folderNone,
                  subtitle: subtitle,
                  editing: _editing,
                  onBack: () => Navigator.maybePop(context),
                  onFolder: () => _move(item, folders),
                  onEdit: () => _startEditing(item),
                  onMore: () => _menu(item),
                ),
              // на мониторе в правке — одна тонкая полоса разметки под строкой; в чтении панели нет
              if (desk && _editing)
                Padding(
                  padding: EdgeInsets.fromLTRB(side, 4, side, 8),
                  child: Container(
                    key: const ValueKey('desk-edit-bar'),
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    decoration: BoxDecoration(color: Tokens.containerHigh, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(child: MarkdownBar(onAction: _markdown, undo: _undo, field: _bodyWindow)),
                        SizedBox(height: 22, child: VerticalDivider(width: 9, thickness: 1, color: Tokens.outline)),
                        _DeskIcon(action: _DeskAction(icon: 'add_photo_alternate', tooltip: l.itemAddPhoto, onTap: _addPhotos)),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Stack(
                  key: _stackKey,
                  children: [
                    ListView(
                      controller: _scroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                      // в правке панель выше: конец текста должен прокручиваться над полосой разметки
                      padding: desk ? EdgeInsets.fromLTRB(side, 6, side, bottom + 24) : EdgeInsets.fromLTRB(12, 6, 12, (_editing ? _editDockHeight : _dockHeight) + _dockGap * 2 + bottom),
                      children: [
                        // файл ещё ложится: вещь уже правится, а показать его пока нечем
                        if (full.copying > 0) ...[
                          _Copying(itemId: item.id, count: full.copying),
                          const SizedBox(height: 18),
                        ],
                        if (videoLink || videoFile != null) ...[
                          VideoCover(
                            itemId: item.id,
                            coverPath: item.coverPath ?? cover?.path,
                            filesRoot: filesRoot,
                            onPlay: openMain,
                            source: videoLink ? source : null,
                            duration: duration,
                          ),
                          if (facts.where((fact) => fact.kind == FactKind.frame).toList() case final frames when frames.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            VideoFrames(frames: frames, filesRoot: filesRoot, onPlay: openMain),
                          ],
                          const SizedBox(height: 18),
                        ] else if (linkLike) ...[
                          LinkPreviewCard(item: item, filesRoot: filesRoot, onOpen: openMain),
                          if (item.goneAt != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                              child: Row(
                                children: [
                                  Icon(symbolIcon('link_off'), size: 16, color: Tokens.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      articleMinutes(facts) != null ? l.readerGone : l.linkGone,
                                      style: TextStyle(fontSize: 13, color: Tokens.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // статья сохранена текстом: читать в Stowa, без сети
                          if (articleMinutes(facts) case final minutes?) ...[
                            const SizedBox(height: 10),
                            ReadButton(minutes: minutes, onTap: () => Navigator.of(context).push(readerRoute(_id))),
                          ],
                          const SizedBox(height: 18),
                        ] else if (cover != null && !galleryBelow) ...[
                          _PhotoCover(
                            image: cover,
                            filesRoot: filesRoot,
                            onOpen: () => PhotoViewer.open(context, [for (final image in gallery) p.join(filesRoot.path, image.path)], _cover.clamp(0, gallery.length - 1)),
                          ),
                          if (gallery.length > 1) ...[
                            const SizedBox(height: 8),
                            _Thumbs(images: gallery, filesRoot: filesRoot, selected: _cover, onPick: (index) => setState(() => _cover = index)),
                          ],
                          const SizedBox(height: 18),
                        ] else
                          const SizedBox(height: 12),
                        if (showTitle)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: _editing
                                ? TextField(
                                    controller: _title,
                                    maxLines: null,
                                    textCapitalization: TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) => _bodyFocus.requestFocus(),
                                    inputFormatters: [TextInputFormatter.withFunction(smartPunctuation)],
                                    style: titleStyle,
                                    decoration: _bare(l.itemTitleHint),
                                  )
                                : GestureDetector(onTap: () => _startEditing(item), child: Text(shownTitle(item.title), style: linkLike ? titleStyle.copyWith(fontSize: 22) : titleStyle)),
                          ),
                        if (videoLink && item.previewAuthor != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                            child: Text(item.previewAuthor!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Tokens.onSurfaceVariant)),
                          ),
                        // монитор: свойства таблицей, как в макете, черта под ними
                        if (desk) ...[
                          SizedBox(height: showTitle ? 18 : 4),
                          _DeskProps(
                            key: const ValueKey('desk-props'),
                            rows: [
                              _PropRow(
                                icon: 'folder',
                                label: l.itemPropFolder,
                                onTap: () => _move(item, folders),
                                child: _PropChip(
                                  icon: folder?.icon ?? 'inbox',
                                  label: folder?.name ?? l.folderNone,
                                  color: folder?.color,
                                ),
                              ),
                              _PropRow(
                                icon: 'sell',
                                label: l.itemPropTags,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final tag in full.tags.keys)
                                      _TagPill(
                                        key: ValueKey('item-tag-$tag'),
                                        label: '#$tag',
                                        removeTooltip: l.removeChip,
                                        onRemove: _editing ? () => ref.read(tagsRepositoryProvider).unlink(_id, tag) : null,
                                        // касание тега — главная с поиском по нему (STOWA-10)
                                        onTap: _editing ? null : () => showTagNotes(context, tag),
                                        tapTooltip: l.tagShowNotes(tag),
                                      ),
                                    _TagPill(label: l.tagAdd, short: l.tagAddShort, add: true, onTap: _addTag),
                                  ],
                                ),
                              ),
                              if (item.reminderAt != null)
                                _PropRow(
                                  icon: 'notifications',
                                  label: l.itemPropRemind,
                                  onTap: () => _reminderMenu(item.reminderAt!),
                                  child: _PropChip(icon: 'event', label: _whenLabel(l, item.reminderAt!, now)),
                                )
                              else if (_placeOf(item) case final place?)
                                _PropRow(
                                  icon: 'notifications',
                                  label: l.itemPropRemind,
                                  onTap: () => _placeMenu(place),
                                  child: _PropChip(icon: remindPlaceIcon(place.kind), label: remindPlaceLabel(l, place.kind, name: place.name, day: place.day)),
                                ),
                              // место есть всегда: у готовой заметки без места его ставят здесь же
                              _PropRow(
                                icon: 'location_on',
                                label: l.itemPropPlace,
                                onTap: item.latitude == null ? null : () => editNotePlace(context, ref, item),
                                child: item.latitude == null
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        // подпись строки уже «Место»: на пилюле не повторяем
                                        child: _TagPill(key: const ValueKey('place-add'), label: l.itemPlaceAdd, add: true, onTap: () => editNotePlace(context, ref, item)),
                                      )
                                    : _PropText(item.placeName ?? l.mapPlaceUnnamed),
                              ),
                              _PropRow(
                                key: const ValueKey('item-date'),
                                icon: 'calendar_today',
                                label: l.itemPropCreated,
                                onTap: () => _changeDate(item),
                                child: _PropText(_whenLabel(l, item.createdAt, now), numbers: true),
                              ),
                              if (photoTakenLine(l, facts, now) case final taken?) _PropRow(icon: 'photo_camera', label: l.itemPropTaken, child: _PropText(taken)),
                              _PropRow(
                                icon: 'link',
                                label: l.itemPropLinks,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _TagPill(key: const ValueKey('link-add'), label: l.linkAdd, short: l.linkAddShort, add: true, onTap: _addLink),
                                ),
                              ),
                            ],
                          ),
                          _RepeatLine(itemId: _id, now: now),
                          Padding(padding: const EdgeInsets.fromLTRB(6, 14, 6, 6), child: Divider(height: 1, thickness: 1, color: Tokens.outline)),
                        ],
                        // когда и где сохранено: место открывает карту
                        if (!desk) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                          child: _WhenWhere(
                            at: item.createdAt,
                            now: now,
                            onDate: () => _changeDate(item),
                            place: item.latitude == null ? null : (item.placeName ?? l.mapPlaceUnnamed),
                            onPlace: () => editNotePlace(context, ref, item),
                            taken: photoTakenLine(l, facts, now),
                          ),
                        ),
                        _RepeatLine(itemId: _id, now: now),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in full.tags.keys)
                                _TagPill(
                                  key: ValueKey('item-tag-$tag'),
                                  label: '#$tag',
                                  removeTooltip: l.removeChip,
                                  // снять тег можно в правке; в просмотре касание — главная с поиском по тегу (STOWA-10)
                                  onRemove: _editing ? () => ref.read(tagsRepositoryProvider).unlink(_id, tag) : null,
                                  onTap: _editing ? null : () => showTagNotes(context, tag),
                                  tapTooltip: l.tagShowNotes(tag),
                                ),
                              _TagPill(label: l.tagAdd, short: l.tagAddShort, add: true, onTap: _addTag),
                              _TagPill(key: const ValueKey('link-add'), label: l.linkAdd, short: l.linkAddShort, add: true, onTap: _addLink),
                              // место есть — оно строкой под датой, касание меняет его там
                              if (item.latitude == null)
                                _TagPill(key: const ValueKey('place-add'), label: l.itemPlaceAdd, short: l.itemPlaceAddShort, add: true, onTap: () => editNotePlace(context, ref, item)),
                            ],
                          ),
                        ),
                        // теги автора ролика или поста: касание ставит тег
                        if (!_editing && SuggestedTags.of(facts, full.tags.keys.toSet()).isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: SuggestedTags(facts: facts, own: full.tags.keys.toSet(), onAdd: (tag) => ref.read(tagsRepositoryProvider).link(_id, tag)),
                          ),
                        ],
                        if (item.reminderAt != null) ...[
                          const SizedBox(height: 18),
                          _ReminderBlock(
                            at: item.reminderAt!,
                            now: now,
                            onTap: () => _reminderMenu(item.reminderAt!),
                            onChange: () => _pickReminder(item.reminderAt),
                          ),
                        ],
                        if (_placeOf(item) case final place?) ...[
                          const SizedBox(height: 18),
                          _PlaceReminderBlock(place: place, onTap: () => _placeMenu(place)),
                        ],
                        ],
                        // что страница сказала о себе: рецепт, товар, событие, место, статья, фильм
                        if (!_editing && PageCard.hasAny(facts)) ...[
                          const SizedBox(height: 12),
                          PageCard(facts: facts, now: now, onShopping: (ingredients) => _shoppingList(item, ingredients)),
                        ],
                        for (final voice in voices) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                            decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                            child: VoicePlayer(path: p.join(filesRoot.path, voice.path), seedId: voice.id, large: true),
                          ),
                        ],
                        // монитор, заметка без текста: под свойствами приглашение дописать
                        if (desk && !_editing && blocks.isEmpty && !linkLike && videoFile == null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.text,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _startEditing(item, append: true),
                                child: Text(l.itemWriteMore, style: bodyStyle.copyWith(color: Tokens.muted)),
                              ),
                            ),
                          ),
                        if (_editing || blocks.isNotEmpty) ...[
                          SizedBox(height: desk ? 4 : 12),
                          AnimatedContainer(
                            key: const ValueKey('item-body-card'),
                            duration: Motion.medium,
                            // на мониторе текст лежит на странице, как в макете, а не в карточке
                            padding: desk ? const EdgeInsets.fromLTRB(6, 10, 6, 10) : const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            decoration: desk ? null : BoxDecoration(color: _editing ? Tokens.containerHigh : Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                            child: _editing
                                ? Focus(
                                    // Tab в формуле — к следующему полю, как в Latex Suite; вне формулы — как обычно
                                    canRequestFocus: false,
                                    skipTraversal: true,
                                    onKeyEvent: (node, event) => mathTabKey(_bodyWindow, event),
                                    // длинная заметка: на каждую букву верстается только кусок у курсора
                                    // (тестировщик 22.11: «длинный текст лагает, 10 FPS»)
                                    child: WindowedTextField(
                                      document: _body,
                                      window: _bodyWindow,
                                      pieceController: (text) => MarkdownController(text: text),
                                      focusNode: _bodyFocus,
                                      undoController: _undo,
                                      // картинка с клавиатуры телефона (Gboard) и «Вставить» из меню — в текст на место курсора
                                      contentInsertionConfiguration: ref.watch(keyboardContentProvider),
                                      contextMenuBuilder: ref.watch(pasteMenuProvider),
                                      inputFormatters: [
                                        TextInputFormatter.withFunction(continueLists),
                                        TextInputFormatter.withFunction(closeWikiBrackets),
                                        TextInputFormatter.withFunction(mathInput),
                                        TextInputFormatter.withFunction(smartPunctuation),
                                      ],
                                      textCapitalization: TextCapitalization.sentences,
                                      // строка с курсором не прячется под плавающую панель и полосу разметки над ней
                                      scrollPadding: const EdgeInsets.only(bottom: _editDockHeight + _dockGap * 2 + 24),
                                      style: bodyStyle,
                                      decoration: _bare(l.itemBodyHint),
                                    ),
                                  )
                                : NoteBody(blocks: blocks, onToggle: (index) => _toggle(item, index), onEdit: () => _startEditing(item), onLink: _openLink, image: inlineImage),
                          ),
                        ],
                        if (galleryBelow && cover != null) ...[
                          const SizedBox(height: 12),
                          _PhotoCover(
                            key: const ValueKey('item-gallery-below'),
                            image: cover,
                            filesRoot: filesRoot,
                            onOpen: () => PhotoViewer.open(context, [for (final image in gallery) p.join(filesRoot.path, image.path)], _cover.clamp(0, gallery.length - 1)),
                          ),
                          if (gallery.length > 1) ...[
                            const SizedBox(height: 8),
                            _Thumbs(images: gallery, filesRoot: filesRoot, selected: _cover, onPick: (index) => setState(() => _cover = index)),
                          ],
                        ],
                        // ссылка среди строк заметки: карточка под текстом, как в мессенджерах
                        if (!_editing && item.kind == ItemKind.note && url != null && item.previewAt != null) ...[
                          const SizedBox(height: 12),
                          LinkPreviewCard(item: item, filesRoot: filesRoot, onOpen: () => _openLink(url)),
                        ],
                        if (!_editing && highlights.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          HighlightsBlock(highlights: highlights, onOpen: (one) => Navigator.of(context).push(readerRoute(_id, highlightId: one.id))),
                        ],
                        if (!_editing && url != null && ChaptersBlock.hasAny(facts)) ...[
                          const SizedBox(height: 12),
                          ChaptersBlock(facts: facts, url: url),
                        ],
                        // телефон, почта, сумма и ссылки из текста — кнопками; в правке не мешают
                        if (!_editing && (FactsChips.hasAny(facts) || checklist != null)) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FactsChips(facts: facts, onLink: _openLink, onShoppingList: checklist == null ? null : () => _toChecklist(item, checklist)),
                          ),
                        ],
                        // свойства из файла, которых Stowa не знает: как панель свойств в Obsidian
                        if (!_editing && properties.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          PropertiesBlock(key: const ValueKey('item-properties'), properties: properties, onChanged: (next) => _setProperties(properties, next)),
                        ],
                        if (item.transcript != null && item.transcript!.isNotEmpty) _DeepBlock(title: l.itemTranscript, text: item.transcript!),
                        // описание от ИИ нужно поиску; читать его стоит только у картинки, у заметки оно пересказ её же текста
                        if (images.isNotEmpty && item.aiDescription != null && item.aiDescription!.isNotEmpty) _DeepBlock(title: l.itemDescription, text: item.aiDescription!),
                        // PDF — просмотром, как в Obsidian: страницы, масштаб, «1 из N»
                        for (final file in files)
                          if (isPdfFile(file.mime, file.path)) PdfPanel(path: p.join(filesRoot.path, file.path), mime: file.mime) else FileTile(file: file, filesRoot: filesRoot),
                        if (!_editing) RelatedBlock(itemId: _id, onOpen: (id) => openItem(context, id)),
                      ],
                    ),
                    // на телефоне панель плавает внизу; на широком экране низ у общей строки — панель под шапкой
                    if (!desk) Positioned(left: 12, right: 12, bottom: _dockGap + bottom, child: dock),
                    // курсор в [[…: заметки по словам набранного прямо над строкой с курсором,
                    // у верха экрана — под ней; набранное и курсор не закрываются
                    if (_editing)
                      ListenableBuilder(
                        listenable: Listenable.merge([_bodyWindow, _caret]),
                        builder: (context, _) => switch ((wikiQueryOf(_bodyWindow.value), _mathAtCaret(), _caret.value)) {
                          (final query?, _, final caret?) when _bodyFocus.hasFocus => Positioned.fill(
                            child: LayoutBuilder(builder: (context, box) => _wikiPanel(query, caret, box.maxHeight, bottom)),
                          ),
                          // курсор в формуле: она же готовой над строкой, меняется с каждой буквой
                          (null, final formula?, final caret?) when _bodyFocus.hasFocus => Positioned.fill(
                            child: IgnorePointer(child: LayoutBuilder(builder: (context, box) => _mathPanel(formula, caret, box.maxHeight, bottom))),
                          ),
                          _ => const SizedBox.shrink(),
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// Подсказка «[[» у строки с курсором: над ней, если сверху хватает места, иначе под ней,
  /// но не ниже панели правки. Выше [_wikiMax] не растёт, остальное листается внутри.
  Widget _wikiPanel(String query, Rect caret, double height, double bottom) {
    // вплотную к строке: в щель торчали бы хвосты букв строки выше
    const gap = 2.0;
    const edge = 8.0;
    final dockTop = height - (_dockGap + bottom + _editDockHeight);
    final above = caret.top - gap - edge;
    final below = dockTop - caret.bottom - gap - edge;
    final up = above >= math.min(_wikiMax, 150) || above >= below;
    final room = math.max(0.0, math.min(_wikiMax, up ? above : below));
    final panel = WikiSuggestions(query: query, targets: _linkTargets ?? const [], exceptId: _id, onPick: _pickWiki, onCreate: _createWiki, maxHeight: room);
    return Stack(
      children: [
        if (up)
          Positioned(left: 12, right: 12, bottom: height - caret.top + gap, child: panel)
        else
          Positioned(left: 12, right: 12, top: caret.bottom + gap, child: panel),
      ],
    );
  }

  /// Просмотр формулы у строки с курсором: над ней, у верха экрана — под ней. Касаний не
  /// ловит: только показывает.
  Widget _mathPanel(MathAround formula, Rect caret, double height, double bottom) {
    const gap = 6.0;
    const edge = 8.0;
    const most = 140.0;
    final dockTop = height - (_dockGap + bottom + _editDockHeight);
    final above = caret.top - gap - edge;
    final below = dockTop - caret.bottom - gap - edge;
    final up = above >= 90 || above >= below;
    final room = formula.display ? most : 96.0;
    final panel = MathPreview(
      // своя формула — своё состояние: последняя разобравшаяся не переходит к соседней
      key: ValueKey(formula.start),
      tex: formula.tex,
      display: formula.display,
      maxHeight: room.clamp(0.0, up ? above : below).toDouble(),
    );
    return Stack(
      children: [
        if (up)
          Positioned(left: 12, right: 12, bottom: height - caret.top + gap, child: Align(alignment: Alignment.bottomCenter, child: panel))
        else
          Positioned(left: 12, right: 12, top: caret.bottom + gap, child: Align(alignment: Alignment.topCenter, child: panel)),
      ],
    );
  }

  InputDecoration _bare(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Tokens.muted),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
    isCollapsed: true,
    contentPadding: EdgeInsets.zero,
  );
}

String _capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Круглая кнопка на подложке. Связанная группа задаёт свои углы.
/// «Сохраняю файл · 40 %» с полоской: пока не пропадёт, оригинал удалять рано.
class _Copying extends ConsumerWidget {
  const _Copying({required this.itemId, required this.count});

  final String itemId;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
    final fraction = ref.watch(copyFractionProvider(itemId)).value;
    final label = fraction == null ? l.fileSaving(count) : '${l.fileSaving(count)} · ${(fraction * 100).floor()} %';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(symbolIcon('downloading'), size: 20, color: Tokens.onSurface),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.fileSavingHint, style: text.bodySmall!.copyWith(color: Tokens.onSurfaceVariant)),
          const SizedBox(height: 12),
          CopyingBar(itemId: itemId),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.radius = const BorderRadius.all(Radius.circular(24))});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Tokens.containerHigh,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(dimension: 48, child: Icon(symbolIcon(icon), size: 22, color: Tokens.onSurface)),
        ),
      ),
    );
  }
}

/// Шапка как у поста Togetherly: «назад», пилюля с папкой и днём, справа
/// сцепленные «править» и «ещё». Касание по пилюле перекладывает вещь.
/// Колонка текста заметки на широком экране, как `.doc` в макете веба.
const _deskColumn = 760.0;

/// Действие строки заметки на мониторе: значок с подсказкой.
class _DeskAction {
  const _DeskAction({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Действие уже стоит (напоминание есть): значок залит.
  final bool active;
}

/// Строка заметки на мониторе вместо телефонной шапки и панели (макет веба, `.crumbs`):
/// слева путь папки, каждая часть открывает свою папку; справа значки действий с
/// подсказками и небольшая кнопка главного действия («Дописать», «Открыть», «Смотреть»).
class _DeskBar extends StatelessWidget {
  const _DeskBar({required this.path, required this.onPath, required this.actions, this.accentIcon, this.accentLabel, this.onAccent});

  /// Папки от верхней до своей: (id, имя); id null — «Без папки».
  final List<(String?, String)> path;
  final void Function(String? folderId) onPath;
  final List<_DeskAction> actions;
  final String? accentIcon;
  final String? accentLabel;
  final VoidCallback? onAccent;

  @override
  Widget build(BuildContext context) {
    final crumb = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.muted);
    return SizedBox(
      key: const ValueKey('desk-bar'),
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (final (index, (id, name)) in path.indexed) ...[
                  if (index > 0) Icon(symbolIcon('chevron_right'), size: 16, color: Tokens.muted),
                  Flexible(child: _Crumb(label: name, style: crumb, onTap: () => onPath(id))),
                ],
              ],
            ),
          ),
          for (final action in actions) _DeskIcon(action: action),
          if (accentLabel != null && onAccent != null) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAccent,
              icon: Icon(symbolIcon(accentIcon ?? 'add'), size: 18),
              label: Text(accentLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.accent,
                foregroundColor: Tokens.onAccent,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Часть пути: подсвечивается под мышью, нажатие открывает папку.
class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: Tokens.container,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
  }
}

/// Значок действия: без подложки, под мышью — мягкая подложка.
class _DeskIcon extends StatelessWidget {
  const _DeskIcon({required this.action});

  final _DeskAction action;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.tooltip,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Tokens.containerHigh,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(symbolIcon(action.icon, filled: action.active), size: 20, color: action.active ? Tokens.onSurface : Tokens.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.folder,
    required this.folderName,
    required this.subtitle,
    required this.editing,
    required this.onBack,
    required this.onFolder,
    required this.onEdit,
    required this.onMore,
  });

  final FolderCard? folder;
  final String folderName;
  final String subtitle;
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback onFolder;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          // заметка открыта первой (окно «Поделиться», виджет): возвращаться некуда
          if (Navigator.of(context).canPop()) ...[
            _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: onBack),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Tooltip(
              message: l.itemMove,
              child: Material(
                color: Tokens.containerHigh,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onFolder,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 14),
                      child: Row(
                        children: [
                          // круг с тем же центром, что полукруглый край пилюли: фигура папки
                          // с углами (квадрат, пилюля) выпирала бы из него
                          Container(
                            key: const ValueKey('item-folder-badge'),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: Tokens.graphite, shape: BoxShape.circle),
                            child: Icon(symbolIcon(folder?.icon ?? 'inbox', filled: true), size: 20, color: Tokens.onSurface),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            // подписи шапки растут не больше чем на четверть: иначе на крупном шрифте не влезут в 48 точек
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.25,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(folderName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2, color: Tokens.onSurface)),
                                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.2, color: Tokens.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (editing)
            _RoundButton(icon: 'more_vert', tooltip: l.itemMore, onTap: onMore)
          else ...[
            _RoundButton(
              icon: 'edit',
              tooltip: l.itemEdit,
              onTap: onEdit,
              radius: const BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(8)),
            ),
            const SizedBox(width: 2),
            _RoundButton(
              icon: 'more_vert',
              tooltip: l.itemMore,
              onTap: onMore,
              radius: const BorderRadius.horizontal(left: Radius.circular(8), right: Radius.circular(24)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Пилюля тега. У «добавить» значок плюса и приглушённая подложка.
class _TagPill extends StatelessWidget {
  const _TagPill({super.key, required this.label, this.short, this.add = false, this.onTap, this.onRemove, this.removeTooltip, this.tapTooltip});

  final String label;

  /// Подпись «добавить» на пилюле, полное имя уходит в подсказку.
  final String? short;
  final bool add;
  final VoidCallback? onTap;

  /// Крестик: снять тег только у этой вещи.
  final VoidCallback? onRemove;
  final String? removeTooltip;

  /// Подсказка, что даст касание тега: «Заметки с #работа».
  final String? tapTooltip;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: add ? Tokens.muted : Tokens.onSurfaceVariant);
    final pill = Material(
      color: add ? Tokens.containerLow : Tokens.containerHigh,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? onRemove,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: EdgeInsets.only(left: add ? 8 : 14, right: onRemove != null ? 6 : (add ? 12 : 14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (add) ...[Icon(symbolIcon('add'), size: 18, color: Tokens.muted), const SizedBox(width: 4)],
              Flexible(child: Text(short ?? label, overflow: TextOverflow.ellipsis, style: style)),
              if (onRemove != null) ...[const SizedBox(width: 2), Icon(symbolIcon('close'), size: 18, color: Tokens.muted)],
            ],
          ),
        ),
      ),
    );
    final tip = onRemove != null ? removeTooltip : (add ? label : (onTap != null ? tapTooltip : null));
    return tip == null ? pill : Tooltip(message: tip, child: pill);
  }
}

/// «Вторник, 3 ноября, 20:14 · Ботаника, Кишинёв». Год — только если не нынешний.
/// «Такая же лежит в «Рецептах» с 12 мая»: та же ссылка или картинка уже есть. Касание открывает ту заметку.
class _RepeatLine extends ConsumerWidget {
  const _RepeatLine({required this.itemId, required this.now});

  final String itemId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repeat = ref.watch(repeatProvider(itemId)).value;
    if (repeat == null) return const SizedBox.shrink();
    final l = L.of(context);
    final at = repeat.createdAt;
    final date = at.year == now.year ? DateFormat.MMMMd(l.localeName).format(at) : DateFormat.yMMMMd(l.localeName).format(at);
    final label = repeat.folderName == null ? l.repeatNoFolder(date) : l.repeatIn(repeat.folderName!, date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openItem(context, repeat.id),
        child: Row(
          children: [
            Icon(symbolIcon('content_copy'), size: 17, color: Tokens.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: Tokens.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

/// День и время по-человечески: «Суббота, 21 ноября, 00:41», прошлый год — с годом.
String _whenLabel(L l, DateTime at, DateTime now) {
  final day = at.year == now.year ? DateFormat.MMMMEEEEd(l.localeName).format(at) : DateFormat.yMMMMEEEEd(l.localeName).format(at);
  return '${_capitalized(day)}, ${DateFormat.jm(l.localeName).format(at)}';
}

/// Свойства заметки на мониторе таблицей, как в макете: подпись со значком слева,
/// значение справа.
class _DeskProps extends StatelessWidget {
  const _DeskProps({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
}

/// Строка свойства. Значение, которое можно поменять, под мышью проступает подложкой.
class _PropRow extends StatefulWidget {
  const _PropRow({super.key, required this.icon, required this.label, required this.child, this.onTap});

  final String icon;
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PropRow> createState() => _PropRowState();
}

class _PropRowState extends State<_PropRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tappable = widget.onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            height: 36,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  Icon(symbolIcon(widget.icon), size: 18, color: Tokens.muted),
                  const SizedBox(width: 8),
                  Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(fontSize: 14, color: Tokens.muted))),
                ],
              ),
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
              onEnter: tappable ? (_) => setState(() => _hover = true) : null,
              onExit: tappable ? (_) => setState(() => _hover = false) : null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: Motion.short,
                  curve: Motion.emphasized,
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: _hover ? Tokens.container : Tokens.container.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Значение свойства пилюлей: значок, у папки — в её цвет.
class _PropChip extends StatelessWidget {
  const _PropChip({required this.icon, required this.label, this.color});

  final String icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: tint == null ? Tokens.containerHigh : FolderPalette.tint(tint, 0.16), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(symbolIcon(icon, filled: tint != null), size: 16, color: tint == null ? Tokens.onSurfaceVariant : FolderPalette.ink(tint)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 14))),
        ],
      ),
    );
  }
}

/// Значение свойства строкой.
class _PropText extends StatelessWidget {
  const _PropText(this.text, {this.numbers = false});

  final String text;
  final bool numbers;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 14, color: Tokens.onSurface, fontFeatures: numbers ? const [FontFeature.tabularFigures()] : null),
  );
}

class _WhenWhere extends StatelessWidget {
  const _WhenWhere({required this.at, required this.now, required this.onDate, required this.place, required this.onPlace, this.taken});

  final DateTime at;
  final DateTime now;

  /// Касание по дате: сменить день и время записи.
  final VoidCallback onDate;
  final String? place;
  final VoidCallback onPlace;

  /// Когда и чем снято фото, если EXIF это знает.
  final String? taken;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final day = at.year == now.year ? DateFormat.MMMMEEEEd(l.localeName).format(at) : DateFormat.yMMMMEEEEd(l.localeName).format(at);
    final when = '${_capitalized(day)}, ${DateFormat.jm(l.localeName).format(at)}';
    final style = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3, color: Tokens.onSurfaceVariant);
    Widget part(String icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(symbolIcon(icon), size: 17, color: Tokens.muted),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        GestureDetector(
          key: const ValueKey('item-date'),
          behavior: HitTestBehavior.opaque,
          onTap: onDate,
          child: part('calendar_today', when),
        ),
        if (place != null)
          GestureDetector(
            key: const ValueKey('item-place'),
            onTap: onPlace,
            child: part('location_on', place!),
          ),
        if (taken != null) part('photo_camera', taken!),
      ],
    );
  }
}

/// Напоминание по месту той же светлой плашкой: «Напомнить дома», «Напомнить: Ботаника».
class _PlaceReminderBlock extends StatelessWidget {
  const _PlaceReminderBlock({required this.place, required this.onTap});

  final PlaceReminder place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Material(
      key: const ValueKey('item-place-reminder'),
      color: Tokens.accent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(symbolIcon(remindPlaceIcon(place.kind), filled: true), size: 24, color: Tokens.onAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  remindPlaceLabel(l, place.kind, name: place.name, day: place.day),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Tokens.onAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Напоминание светлой плашкой: заметно сразу и не путается с тегами.
class _ReminderBlock extends StatelessWidget {
  const _ReminderBlock({required this.at, required this.now, required this.onTap, required this.onChange});

  final DateTime at;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final date = _capitalized(DateFormat('EEEE, d MMMM', l.localeName).format(at));
    return Material(
      key: const ValueKey('item-reminder'),
      color: Tokens.accent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(symbolIcon('alarm', filled: true), size: 24, color: Tokens.onAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_capitalized(formatReminder(l, at, now)), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                    Text(date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Tokens.onAccentVariant)),
                  ],
                ),
              ),
              Tooltip(
                message: l.itemReminderChange,
                child: Material(
                  color: Tokens.onAccent.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onChange,
                    child: SizedBox.square(dimension: 44, child: Icon(symbolIcon('edit_calendar'), size: 20, color: Tokens.onAccent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Снимок на странице вещи в своих пропорциях: обрезаются только очень вытянутые.
/// Касание открывает его во весь экран.
class _PhotoCover extends StatelessWidget {
  const _PhotoCover({super.key, required this.image, required this.filesRoot, required this.onOpen, this.radius = Radii.card});

  final Attachment image;
  final Directory filesRoot;
  final VoidCallback onOpen;

  /// Крупно над заголовком — скругление карточки, в тексте — плитки: она внутри карточки текста.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = p.join(filesRoot.path, image.path);
    final width = image.width;
    final height = image.height;
    final ratio = width != null && height != null && width > 0 ? height / width : 0.75;
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          // высота к ширине от 9:16 до 5:4: длинный скриншот не съедает весь экран
          aspectRatio: 1 / ratio.clamp(0.5625, 1.25),
          child: Hero(
            tag: photoHeroTag(path),
            child: FilePicture(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => ColoredBox(color: Tokens.containerHigh),
            ),
          ),
        ),
      ),
    );
  }
}

/// Остальные снимки рядом под крупным: касание ставит снимок крупно.
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.images, required this.filesRoot, required this.selected, required this.onPick});

  final List<Attachment> images;
  final Directory filesRoot;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => onPick(index),
          child: AnimatedOpacity(
            duration: Motion.short,
            opacity: index == selected ? 1 : 0.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.photo),
              child: FilePicture(
                File(p.join(filesRoot.path, images[index].path)),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                cacheWidth: 168,
                errorBuilder: (_, _, _) => SizedBox.square(dimension: 56, child: ColoredBox(color: Tokens.containerHigh)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton {
  const _DockButton({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  final String icon;
  final String tooltip;

  /// null — кнопка выключена: отменять нечего.
  final VoidCallback? onTap;
  final bool active;
}

/// Плавающая панель внизу: пилюля с действиями и светлая кнопка главного шага.
/// На узком экране главная кнопка остаётся значком, подпись уходит в подсказку.
class _Dock extends StatelessWidget {
  const _Dock({required this.height, required this.buttons, required this.accentIcon, required this.accentLabel, required this.onAccent});

  final double height;
  final List<_DockButton> buttons;
  final String accentIcon;
  final String accentLabel;
  final VoidCallback onAccent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 340;
        final radius = BorderRadius.circular(height / 2);
        return Row(
          children: [
            Expanded(
              child: Container(
                height: height,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Tokens.containerHighest, borderRadius: radius),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final button in buttons)
                      Flexible(
                        child: Tooltip(
                          message: button.tooltip,
                          child: Material(
                            color: button.active ? Tokens.onSurface.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(28),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: button.onTap,
                              child: SizedBox(
                                width: 52,
                                height: height - 16,
                                child: Icon(symbolIcon(button.icon, filled: button.active), size: 24, color: button.onTap == null ? Tokens.muted : Tokens.onSurface),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: accentLabel,
              excludeFromSemantics: wide,
              child: Material(
                color: Tokens.accent,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAccent,
                  child: SizedBox(
                    height: height,
                    width: wide ? null : height,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(symbolIcon(accentIcon), size: 22, color: Tokens.onAccent),
                          if (wide) ...[
                            const SizedBox(width: 8),
                            MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.2,
                              child: Text(accentLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tokens.onAccent)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Тег одной вещи руками: имя без решётки.
class _DeepBlock extends StatelessWidget {
  const _DeepBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(color: Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: style.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: Tokens.muted),
          ),
          const SizedBox(height: 4),
          SelectableText(text, style: style.bodyLarge!.copyWith(fontSize: 15, height: 1.45, color: Tokens.onSurfaceVariant)),
        ],
      ),
    );
  }
}

