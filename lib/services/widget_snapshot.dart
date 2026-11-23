/// Что видят виджеты: файл `widget.json` — на iPhone в папке группы `group.app.stowa`,
/// на Android в папке приложения (`NoteWidgetProvider`).
/// Виджет базы не читает — только этот файл, его пишет приложение при каждой правке.
library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../core/theme/folder_palette.dart';
import '../core/user_first.dart';
import '../data/db/database.dart';
import '../domain/note_blocks.dart';
import '../domain/note_links.dart';

/// Сколько заметок уходит в файл: из них выбирают заметку в настройке виджета.
const widgetNoteLimit = 60;

/// Сколько строк заметки показывает самый большой виджет.
const widgetLineLimit = 8;

/// Заметка, которую можно показать в виджете.
class WidgetNote {
  const WidgetNote({required this.id, required this.title, required this.body, this.color, this.pinned = false});

  final String id;
  final String title;
  final String body;

  /// Цвет папки; без папки — нет.
  final Color? color;
  final bool pinned;
}

/// Содержимое `widget.json`. Под «Кодом на вход» заметок в нём нет вовсе: виджет на
/// экране блокировки видит кто угодно.
Map<String, Object?> widgetSnapshot({required List<WidgetNote> notes, required bool locked}) => {
  'version': 1,
  'locked': locked,
  'notes': [
    if (!locked)
      for (final note in notes.take(widgetNoteLimit))
        {
          'id': note.id,
          'title': shownTitle(note.title),
          'lines': [
            for (final line in noteLinesUnderTitle(widgetHead(note.body), note.title).take(widgetLineLimit))
              {'text': line.text, if (line.done != null) 'done': line.done},
          ],
          if (note.color != null) 'color': note.color!.toARGB32(),
          'pinned': note.pinned,
        },
  ],
};

/// Начало заметки, которого хватит на [widgetLineLimit] строк виджета: весь текст длинного
/// конспекта разбирать незачем, а снимок строится на шестьдесят заметок разом.
String widgetHead(String body) {
  const enough = 4000;
  if (body.length <= enough) return body;
  final cut = body.lastIndexOf('\n', enough);
  return body.substring(0, cut > 0 ? cut : enough);
}

/// Канал `stowa/widget` (iPhone и Android): `write` кладёт текст `widget.json` в папку группы или приложения
/// и просит виджеты перерисоваться.
const widgetChannel = MethodChannel('stowa/widget');

/// Держит `widget.json` свежим: пишет при запуске, после каждой правки заметок, папок и
/// фактов (с паузой, чтобы пачка правок дала одну запись) и по [refresh] — замок сменился.
class WidgetSync {
  WidgetSync(this._db, {required bool Function() locked}) : _locked = locked; // ignore: prefer_initializing_formals

  final AppDatabase _db;
  final bool Function() _locked;
  StreamSubscription<void>? _changes;
  Timer? _pause;

  static const _quiet = Duration(milliseconds: 600);

  void start() {
    _changes ??= _db.tableUpdates(TableUpdateQuery.onAllTables([_db.items, _db.folders, _db.facts])).listen((_) => refresh());
    refresh();
  }

  /// Переписать файл после короткой паузы; [now] — сразу (замок сменился: HyperOS убивает
  /// процесс смахиванием, и за паузу текст остался бы на столе).
  void refresh({bool now = false}) {
    _pause?.cancel();
    if (now) {
      _write(now: true).ignore();
    } else {
      _waiting = true;
      _pause = Timer(_quiet, () => _write().ignore());
    }
  }

  // запись ждёт паузы или конца набора
  var _waiting = false;

  /// Ушли из приложения: отложенная запись — сразу. Набор кончился, а процесс могут выгрузить,
  /// и виджет на столе остался бы с прежним текстом.
  void flush() {
    if (_waiting) refresh(now: true);
  }

  Future<void> _write({bool now = false}) async {
    // человек печатает — снимок ждёт: он читает шестьдесят заметок в потоке экрана, а виджет
    // на столе всё равно не виден, пока открыто приложение. Замок пишется сразу
    if (!now) await userFirst.doneTyping();
    _waiting = false;
    var locked = _locked();
    var notes = locked ? const <WidgetNote>[] : await widgetNotes(_db);
    // замок включили, пока база отвечала: закрытый файл уже лёг, текст поверх него не класть
    if (!locked && _locked()) {
      locked = true;
      notes = const [];
    }
    try {
      await widgetChannel.invokeMethod<void>('write', jsonEncode(widgetSnapshot(notes: notes, locked: locked)));
    } on MissingPluginException {
      // виджетов на этой платформе нет
    }
  }

  void dispose() {
    _pause?.cancel();
    _changes?.cancel().ignore();
  }
}

/// Заметки для виджета: живые, не из скрытых папок и без пометки «для взрослых»;
/// закреплённые первыми, потом последние правленые.
Future<List<WidgetNote>> widgetNotes(AppDatabase db, {int limit = widgetNoteLimit}) async {
  final rows = await db.customSelect(
    'SELECT i.id, i.title, i.body, i.pinned_at, f.color AS folder_color, f.sort_order AS folder_order '
    'FROM items i LEFT JOIN folders f ON f.id = i.folder_id '
    'WHERE i.deleted_at IS NULL AND (f.hidden IS NULL OR f.hidden = 0) '
    "AND i.id NOT IN (SELECT item_id FROM facts WHERE kind = 'adult') "
    'ORDER BY i.pinned_at IS NULL, i.pinned_at DESC, i.updated_at DESC LIMIT ?',
    variables: [Variable.withInt(limit)],
    readsFrom: {db.items, db.folders, db.facts},
  ).get();
  return [
    for (final row in rows)
      WidgetNote(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        body: row.read<String>('body'),
        color: row.readNullable<String>('folder_color') == null && row.readNullable<int>('folder_order') == null
            ? null
            : FolderPalette.of(row.readNullable<String>('folder_color'), row.readNullable<int>('folder_order') ?? 0),
        pinned: row.data['pinned_at'] != null,
      ),
  ];
}
