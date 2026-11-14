import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format/reminder_format.dart';
import '../../core/icons/icon_registry.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/sheet_options.dart';
import '../../core/widgets/undo_snack.dart';
import '../../core/widgets/voice_player.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/place_cue.dart' show KnownPlace, parsePlaceCue;
import '../../domain/reminder_parser.dart' show parseReminder, reminderPhrase;
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
import '../composer/panel_text.dart';
import '../composer/smart_punctuation.dart';
import '../composer/wiki_link_edit.dart';
import '../composer/wiki_suggestions.dart';
import '../places/place_kinds.dart';
import '../places/places_screen.dart';
import '../places/reminder_permissions.dart';
import '../composer/picked_files.dart';
import '../folder/folder_sheets.dart';
import '../map/map_screen.dart';
import '../tags/tag_picker.dart';
import '../reader/highlights_block.dart';
import '../reader/reader_screen.dart';
import 'copying_bar.dart';
import 'facts_block.dart';
import 'history_screen.dart';
import 'item_actions.dart' show togglePinned;
import 'page_card.dart';
import 'item_media.dart';
import 'markdown_controller.dart';
import 'note_body.dart';
import 'photo_viewer.dart';
import 'properties_block.dart';
import 'link_sheet.dart';
import 'related_block.dart';

/// Страница въезжает справа, как в макете.
Route<void> itemRoute(String id) => PageRouteBuilder(
  transitionDuration: const Duration(milliseconds: 500),
  reverseTransitionDuration: Motion.medium,
  pageBuilder: (context, animation, secondary) => ItemScreen(id: id),
  transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
    position: Tween(begin: const Offset(1.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
    child: child,
  ),
);

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

enum _MenuAction { pin, copy, date, property, history, delete }

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
  final _body = MarkdownController();
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
    _body.addListener(_watchWiki);
    _body.addListener(_measureCaret);
    _scroll.addListener(_measureCaret);
    _bodyFocus.addListener(_measureCaret);
    // открыл — значит посмотрел: очередь «посмотреть потом» и сводка недели больше о ней не напомнят
    _items.markOpened(widget.id, _clock()).ignore();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    // ушли посреди правки — набранное не теряется
    if (_editing) _save();
    _title.dispose();
    _body.dispose();
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
    final now = '${_title.text}\n${_body.text}';
    if (ref.read(placesProvider).value case final places?) _known = _knownOf(places);
    _seenPhrase = reminderPhrase(now, _clock(), workEnd: _workEnd());
    _seenPlace = _placePhrase(now);
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

  String? _placePhrase(String text) {
    final cue = parsePlaceCue(text, places: _known);
    return cue == null ? null : '${cue.kind.name}|${cue.placeId}|${text.substring(cue.start, cue.end).toLowerCase()}';
  }

  void _changed() {
    if (!_editing) return;
    final text = '${_title.text}\n${_body.text}';
    final phrase = reminderPhrase(text, _clock(), workEnd: _workEnd());
    if (phrase != _seenPhrase) _timeTouched = true;
    _seenPhrase = phrase;
    final place = _placePhrase(text);
    if (place != _seenPlace) _placeTouched = true;
    _seenPlace = place;
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, _save);
  }

  Future<void> _save() async {
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
    if (_linkTargets != null || wikiQueryOf(_body.value) == null) return;
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

  void _measureCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // меряем, только пока подсказка нужна: после правки поля уже нет
      if (!_editing || !_bodyFocus.hasFocus || wikiQueryOf(_body.value) == null) {
        _caret.value = null;
        return;
      }
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final editable = _bodyFocus.context?.findAncestorStateOfType<EditableTextState>()?.renderEditable;
      final selection = _body.selection;
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
  Future<void> _changeDate(Item item) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showOptionsSheet<String>(
      context,
      title: l.itemDateChange,
      options: [
        SheetChoice(value: 'now', title: l.itemDateNow, icon: 'schedule'),
        SheetChoice(value: 'pick', title: l.itemDatePick, icon: 'calendar_today'),
      ],
    );
    if (choice == null || !mounted) return;
    final now = _clock();
    final before = item.createdAt;
    var chosen = now;
    if (choice == 'pick') {
      final start = before.isAfter(now) ? now : before;
      final day = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(1970), lastDate: now);
      if (day == null || !mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
      if (time == null) return;
      chosen = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (chosen.isAfter(now)) chosen = now;
    }
    if (chosen == before) return;
    await _items.setCreated(_id, chosen);
    showUndo(messenger, message: l.itemDateChanged, label: l.undo, overDock: true, onUndo: () => _items.setCreated(_id, before));
  }

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
    final navigator = Navigator.of(context);
    final text = '${l.shoppingFor(item.title)}\n${[for (final ingredient in ingredients) '- [ ] $ingredient'].join('\n')}';
    final id = await ref.read(captureServiceProvider).capture(CaptureInput(text: text, detectReminder: false));
    showUndo(messenger, message: l.shoppingReady, label: l.actionOpen, onUndo: () => navigator.push(itemRoute(id)), overDock: true);
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
      final taken = {
        for (final file in ref.read(itemProvider(_id)).value?.attachments ?? const <Attachment>[]) p.basename(file.path).replaceFirst(RegExp(r'^\d+_'), '').toLowerCase(),
      };
      final now = _clock();
      final files = <PickedFile>[];
      for (final file in picked) {
        final extension = p.extension(file.path).replaceFirst('.', '').toLowerCase();
        final name = photoFileName(now, extension.isEmpty ? 'jpg' : extension, taken);
        taken.add(name.toLowerCase());
        final one = await pickedFrom(file.path, hint: file.mimeType);
        files.add(PickedFile(path: one.path, mime: one.mime, size: one.size, name: name));
      }
      await ref.read(captureServiceProvider).attach(_id, files);
      if (!mounted) return;
      _body.value = insertImageLines(caret, [for (final file in files) file.name!]);
      _bodyFocus.requestFocus();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).attachFailed)));
    }
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
        final navigator = Navigator.of(context);
        showUndo(
          messenger,
          message: l.linkMissing(title),
          label: l.linkCreateAction,
          overDock: true,
          onUndo: () async {
            final id = await _createNote(title);
            if (mounted) await navigator.push(itemRoute(id));
          },
        );
        return;
      }
      await Navigator.of(context).push(itemRoute(target));
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.of(context).itemCopied)));
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _autosave?.cancel();
    _editing = false;
    await _items.softDelete(_id, _clock());
    if (mounted) Navigator.pop(context);
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
        SheetChoice(value: _MenuAction.copy, title: l.itemCopy, icon: 'content_copy'),
        SheetChoice(value: _MenuAction.date, title: l.itemDateChange, icon: 'calendar_today'),
        SheetChoice(value: _MenuAction.property, title: l.propertyAdd, icon: 'list_alt'),
        if (hasHistory) SheetChoice(value: _MenuAction.history, title: l.historyTitle, icon: 'history'),
        SheetChoice(value: _MenuAction.delete, title: l.itemDelete, icon: 'delete', danger: true),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _MenuAction.pin:
        await togglePinned(context, ref, id: _id, pinned: item.pinnedAt != null, overDock: false);
      case _MenuAction.copy:
        await _copy(item);
      case _MenuAction.date:
        await _changeDate(item);
      case _MenuAction.property:
        await _addProperty(item);
      case _MenuAction.history:
        await _history();
      case _MenuAction.delete:
        await _delete();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final text = Theme.of(context).textTheme;
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
    final folder = folders.where((one) => one.id == item.folderId).firstOrNull;
    final images = full.attachments.where((file) => file.mime.startsWith('image/')).toList();
    // фото, вставленные в текст, стоят на своём месте в тексте, а не крупно над заголовком
    final attachmentPaths = [for (final file in full.attachments) file.path];
    final inline = {for (final name in embedNames(item.body)) ?embedPath(name, attachmentPaths)};
    final gallery = [for (final image in images) if (!inline.contains(image.path)) image];
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
    final files = full.attachments.where((file) => !file.mime.startsWith('image/') && !file.mime.startsWith('audio/') && file != videoFile).toList();
    // адрес уже стоит в превью: строкой в тексте он не повторяется
    final shownBody = linkLike ? item.body.split('\n').where((line) => line.trim() != url).join('\n') : item.body;
    final blocks = parseNoteBlocks(shownBody);
    // «купить молоко, хлеб и яйца» можно одним касанием сделать галочками
    final checklist = item.kind == ItemKind.note ? shoppingChecklist(item.body) : null;
    final properties = unpackVaultProperties(item.properties);
    // заголовок из первой строки над ней же не повторяется: заметка видна, как её написали
    final showTitle = _editing || linkLike || !titleIsFirstLine(shownBody, item.title);
    final source = url == null ? null : sourceName(Uri.tryParse(url)?.host ?? '');
    final duration = item.durationSeconds == null ? null : Duration(seconds: item.durationSeconds!);
    Future<void> openMain() => videoFile != null ? openLocalFile(context, p.join(filesRoot.path, videoFile.path), videoFile.mime) : _openLink(url!);
    final titleStyle = text.headlineSmall!.copyWith(fontSize: 25, height: 1.2, letterSpacing: -0.4);
    final bodyStyle = text.bodyLarge!.copyWith(fontSize: 16, height: 1.5, color: Tokens.onSurface);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final cover = gallery.isEmpty ? null : gallery[_cover.clamp(0, gallery.length - 1)];
    // картинка из текста по имени; касание открывает просмотр всех фото заметки на ней
    Widget inlineImage(String name) {
      final path = embedPath(name, attachmentPaths);
      final image = images.where((one) => one.path == path).firstOrNull;
      if (image == null) return MissingImage(name: name);
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

    return PopScope(
      // «назад» посреди правки сначала закрывает правку, сохранив текст
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
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
              Expanded(
                child: Stack(
                  key: _stackKey,
                  children: [
                    ListView(
                      controller: _scroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                      // в правке панель выше: конец текста должен прокручиваться над полосой разметки
                      padding: EdgeInsets.fromLTRB(12, 6, 12, (_editing ? _editDockHeight : _dockHeight) + _dockGap * 2 + bottom),
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
                        ] else if (cover != null) ...[
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
                        // когда и где сохранено: место открывает карту
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                          child: _WhenWhere(
                            at: item.createdAt,
                            now: now,
                            onDate: () => _changeDate(item),
                            place: item.latitude == null ? null : (item.placeName ?? l.mapPlaceUnnamed),
                            onPlace: () => Navigator.of(context).push(mapRoute(focusItemId: _id)),
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
                                  label: '#$tag',
                                  removeTooltip: l.removeChip,
                                  // снять тег можно в правке, в просмотре пилюля просто называет его
                                  onRemove: _editing ? () => ref.read(tagsRepositoryProvider).unlink(_id, tag) : null,
                                ),
                              _TagPill(label: l.tagAdd, short: l.tagAddShort, add: true, onTap: _addTag),
                              _TagPill(key: const ValueKey('link-add'), label: l.linkAdd, short: l.linkAddShort, add: true, onTap: _addLink),
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
                        if (_editing || blocks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            key: const ValueKey('item-body-card'),
                            duration: Motion.medium,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            decoration: BoxDecoration(color: _editing ? Tokens.containerHigh : Tokens.container, borderRadius: BorderRadius.circular(Radii.card)),
                            child: _editing
                                ? TextField(
                                    controller: _body,
                                    focusNode: _bodyFocus,
                                    undoController: _undo,
                                    // поле растёт с текстом: одна строка — одна строка, без пустоты под ней
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    inputFormatters: [
                                      TextInputFormatter.withFunction(continueLists),
                                      TextInputFormatter.withFunction(closeWikiBrackets),
                                      TextInputFormatter.withFunction(smartPunctuation),
                                    ],
                                    textCapitalization: TextCapitalization.sentences,
                                    // строка с курсором не прячется под плавающую панель и полосу разметки над ней
                                    scrollPadding: const EdgeInsets.only(bottom: _editDockHeight + _dockGap * 2 + 24),
                                    style: bodyStyle,
                                    decoration: _bare(l.itemBodyHint),
                                  )
                                : NoteBody(blocks: blocks, onToggle: (index) => _toggle(item, index), onEdit: () => _startEditing(item), onLink: _openLink, image: inlineImage),
                          ),
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
                        for (final file in files) FileTile(file: file, filesRoot: filesRoot),
                        if (!_editing) RelatedBlock(itemId: _id, onOpen: (id) => Navigator.of(context).push(itemRoute(id))),
                      ],
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: _dockGap + bottom,
                      child: AnimatedSwitcher(
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
                                    child: MarkdownBar(onAction: _markdown),
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
                            : _Dock(
                                key: const ValueKey('view-dock'),
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
                                  _DockButton(icon: 'share', tooltip: l.itemShare, onTap: () => _share(item, full.attachments, filesRoot)),
                                ],
                                accentIcon: videoLink || videoFile != null ? 'play_arrow' : (linkLike ? 'open_in_new' : 'add'),
                                accentLabel: videoLink || videoFile != null ? l.itemWatch : (linkLike ? l.itemOpenLink : l.itemAppend),
                                onAccent: linkLike || videoFile != null ? openMain : () => _startEditing(item, append: true),
                              ),
                      ),
                    ),
                    // курсор в [[…: заметки по словам набранного прямо над строкой с курсором,
                    // у верха экрана — под ней; набранное и курсор не закрываются
                    if (_editing)
                      ListenableBuilder(
                        listenable: Listenable.merge([_body, _caret]),
                        builder: (context, _) => switch ((wikiQueryOf(_body.value), _caret.value)) {
                          (final query?, final caret?) when _bodyFocus.hasFocus => Positioned.fill(
                            child: LayoutBuilder(builder: (context, box) => _wikiPanel(query, caret, box.maxHeight, bottom)),
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
          _RoundButton(icon: 'arrow_back', tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: onBack),
          const SizedBox(width: 8),
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
  const _TagPill({super.key, required this.label, this.short, this.add = false, this.onTap, this.onRemove, this.removeTooltip});

  final String label;

  /// Подпись «добавить» на пилюле, полное имя уходит в подсказку.
  final String? short;
  final bool add;
  final VoidCallback? onTap;

  /// Крестик: снять тег только у этой вещи.
  final VoidCallback? onRemove;
  final String? removeTooltip;

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
    final tip = onRemove != null ? removeTooltip : (add ? label : null);
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
        onTap: () => Navigator.of(context).push(itemRoute(repeat.id)),
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
  const _PhotoCover({required this.image, required this.filesRoot, required this.onOpen, this.radius = Radii.card});

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
            child: Image.file(
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
              child: Image.file(
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
  const _Dock({super.key, required this.height, required this.buttons, required this.accentIcon, required this.accentLabel, required this.onAccent});

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

