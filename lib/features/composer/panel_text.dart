import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../core/format/reminder_format.dart';
import '../../domain/item_kind.dart';
import '../../domain/item_title.dart';
import '../../domain/line_query.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import 'panel_model.dart';

/// Ключи команд: язык интерфейса первым, русский и английский всегда, чтобы
/// `/задача` и `/task` работали при любом языке.
Map<LineCommand, List<String>> commandKeys(L l) {
  final languages = [l, lookupL(const Locale('ru')), lookupL(const Locale('en'))];
  String key(L one, LineCommand command) => switch (command) {
    LineCommand.remind => one.cmdRemind,
    LineCommand.task => one.cmdTask,
    LineCommand.list => one.cmdList,
    LineCommand.find => one.cmdFind,
    LineCommand.inbox => one.cmdInbox,
  };
  return {
    for (final command in LineCommand.values) command: {for (final one in languages) key(one, command)}.toList(),
  };
}

String commandHint(L l, LineCommand command) => switch (command) {
  LineCommand.remind => l.cmdRemindHint,
  LineCommand.task => l.cmdTaskHint,
  LineCommand.list => l.cmdListHint,
  LineCommand.find => l.cmdFindHint,
  LineCommand.inbox => l.cmdInboxHint,
};

String kindsLabel(L l, ItemKind kind) => switch (kind) {
  ItemKind.note => l.kindsNote,
  ItemKind.link => l.kindsLink,
  ItemKind.video => l.kindsVideo,
  ItemKind.image => l.kindsImage,
  ItemKind.file => l.kindsFile,
  ItemKind.voice => l.kindsVoice,
};

String kindLabel(L l, ItemKind kind) => switch (kind) {
  ItemKind.note => l.kindNote,
  ItemKind.link => l.kindLink,
  ItemKind.video => l.kindVideo,
  ItemKind.image => l.kindImage,
  ItemKind.file => l.kindFile,
  ItemKind.voice => l.kindVoice,
};

/// Заголовок вещи, у которой нет ни текста, ни человеческого имени файла:
/// «Фото от 3 ноября». По нему же вещь находится поиском.
String untitledFor(L l, {required String mime, required String fileName, required DateTime at}) {
  final date = DateFormat.MMMMd(l.localeName).format(at);
  if (mime.startsWith('image/')) return isScreenshotName(fileName) ? l.untitledScreenshot(date) : l.untitledPhoto(date);
  if (mime.startsWith('video/')) return l.untitledVideo(date);
  if (mime.startsWith('audio/')) return l.untitledAudio(date);
  return l.untitledFile(date);
}

String kindIcon(ItemKind kind) => switch (kind) {
  ItemKind.note => 'description',
  ItemKind.link => 'link',
  ItemKind.video => 'play_arrow',
  ItemKind.image => 'image',
  ItemKind.file => 'draft',
  ItemKind.voice => 'graphic_eq',
};

/// «сегодня», «вчера» или «12 окт.»
String shortDate(L l, DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l.dateToday;
  if (days == 1) return l.dateYesterday;
  return DateFormat.MMMd(l.localeName).format(at);
}

/// Где нашлось, если не в самом тексте.
String deepLabel(L l, ItemKind kind) => switch (kind) {
  ItemKind.voice || ItemKind.video => l.foundInTranscript,
  ItemKind.image => l.foundOnImage,
  _ => l.foundInDescription,
};

String saveTitle(L l, SavePlan plan, DateTime now) {
  final command = plan.command;
  if (command == LineCommand.remind) return plan.remindAt == null ? l.saveRemindBare : l.saveRemind(formatReminder(l, plan.remindAt!, now));
  if (command == LineCommand.inbox) return l.saveAsIs;
  final what = command == LineCommand.task
      ? l.saveWhatTask
      : command == LineCommand.list
      ? l.saveWhatList(plan.listCount)
      : plan.attachments > 0
      ? (plan.onlyMedia ? l.saveWhatPhotos(plan.attachments) : l.saveWhatFiles(plan.attachments))
      : switch (plan.kind) {
          ItemKind.link => l.saveWhatLink,
          ItemKind.video => l.saveWhatVideo,
          _ => l.saveWhatNote,
        };
  final folder = plan.folder;
  return folder == null ? l.saveNoFolder(what) : l.saveInto(what, folder.name);
}

/// Подпись под «Закинуть»: теги от правил, напоминание или заголовок будущей вещи.
({String text, bool alarm}) saveSub(L l, SavePlan plan, String rest, DateTime now) {
  final parts = <String>[];
  if (plan.autoTags.isNotEmpty) parts.add(plan.autoTags.map((tag) => '#$tag').join(' '));
  final remind = plan.remindAt;
  if (remind != null && plan.command != LineCommand.remind) parts.add(l.saveRemindAt(formatReminder(l, remind, now)));
  if (plan.command == LineCommand.remind && remind == null) parts.add(l.saveRemindWhen);
  if (parts.isEmpty) {
    final url = firstUrl(rest);
    final title = titleFor(rest);
    parts.add(
      title.isNotEmpty
          ? title
          : plan.attachments > 0
          ? l.savePhotosHint
          : url == null
          ? ''
          : sourceName(url.host),
    );
  }
  return (text: parts.join(' · '), alarm: remind != null && plan.command != LineCommand.remind && plan.autoTags.isEmpty);
}

/// Почему сюда: свой выбор, правило или похожее без сети.
({String text, String icon}) saveWhere(L l, SavePlan plan) {
  final value = plan.reasonValue ?? '';
  return switch (plan.reason) {
    SaveReason.chosen => (text: l.reasonChosen, icon: 'touch_app'),
    SaveReason.asIs => (text: l.reasonAsIs, icon: 'inbox'),
    SaveReason.tag => (text: l.reasonTag(value), icon: 'bolt'),
    SaveReason.word => (text: l.reasonWord(value), icon: 'bolt'),
    SaveReason.domain => (text: l.reasonDomain(value), icon: 'bolt'),
    SaveReason.kind => (text: l.reasonKind, icon: 'bolt'),
    SaveReason.name => (text: l.reasonName(value), icon: 'bolt'),
    // вид вещи или тип файла словами не назвать: тогда причина — вид
    SaveReason.similar => (text: value.isEmpty ? l.reasonKind : l.reasonSimilar(value), icon: 'bolt'),
    SaveReason.none => (text: l.reasonNone, icon: 'inbox'),
  };
}

/// Подпись и значок кнопки для выбранной строки.
({String label, String icon}) actionOf(L l, PanelRow row) => switch (row) {
  SaveRow(:final plan) => (label: plan.command == LineCommand.remind ? l.actionRemind : l.actionStow, icon: 'arrow_upward'),
  ResultRow() => (label: l.actionOpen, icon: 'arrow_outward'),
  NewTagRow() || NewFolderRow() => (label: l.actionCreate, icon: 'keyboard_return'),
  TagRow() || FolderRow() || CommandRow() => (label: l.actionInsert, icon: 'keyboard_return'),
};
