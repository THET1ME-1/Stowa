import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../../domain/note_blocks.dart' show checkLine;
import '../../domain/return_plan.dart';
import '../../domain/tag_name.dart';
import '../db/database.dart';

/// Ролик или статья в очереди «посмотреть потом».
class WatchLaterEntry {
  const WatchLaterEntry({required this.id, required this.title, required this.minutes, required this.isVideo});

  final String id;
  final String title;
  final int minutes;
  final bool isVideo;
}

/// «В этот день»: что вспомнить и какие заметки показать.
class OnThisDay {
  const OnThisDay({required this.found, required this.ids});

  final OnThisDayFound found;

  /// Старые первыми: так их и сохраняли.
  final List<String> ids;
}

/// Сводка недели и её списки для экрана.
class WeekSummary {
  const WeekSummary({required this.found, required this.unopened, required this.unsorted});

  final WeekFound found;
  final List<String> unopened;
  final List<String> unsorted;
}

/// Что купить: заметка и её неотмеченные пункты (пусто — заметка с тегом без списка).
class ShoppingList {
  const ShoppingList({required this.id, required this.title, required this.items});

  final String id;
  final String title;
  final List<String> items;
}

/// Очередь — только свежее: старое человек уже не посмотрит, напоминать о нём — шум.
const _watchDays = 30;

// тег покупок на семи языках и начало заметки-списка, которую делает «В список покупок»
const _shoppingTags = {'купить', 'buy', 'купити', 'cumpără', 'kupić', 'kaufen', 'comprar'};
final _shoppingTitle = RegExp(r'^(купить|buy|купити|de cumpărat|kaufen|kupić|comprar)\s*:', caseSensitive: false);

/// Что вернуть человеку: очередь, «в этот день», неделя, покупки. Время в базе — текстом,
/// поэтому даты сравниваются в Dart, а не строками в SQL.
class ReturnRepository {
  ReturnRepository(this._db);

  final AppDatabase _db;

  Future<List<Item>> _alive() => (_db.select(_db.items)..where((t) => t.deletedAt.isNull())).get();

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Непросмотренные ролики и статьи за 30 дней, у которых известна длина. Свежие первыми.
  Future<List<WatchLaterEntry>> watchLater(DateTime now) async {
    final since = now.subtract(const Duration(days: _watchDays));
    final items = [
      for (final item in await _alive())
        if ((item.kind == ItemKind.video || item.kind == ItemKind.link) && item.openedAt == null && item.createdAt.isAfter(since)) item,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.isEmpty) return const [];
    final reading = {
      for (final fact in await (_db.select(_db.facts)..where((t) => t.kind.equals(FactKind.readingTime.name) & t.itemId.isIn([for (final item in items) item.id]))).get())
        fact.itemId: fact.number?.round() ?? int.tryParse(fact.value) ?? 0,
    };
    final queue = <WatchLaterEntry>[];
    for (final item in items) {
      final seconds = item.durationSeconds ?? 0;
      // у ролика — длина, у статьи — время чтения; без них сколько займёт — не сказать
      final minutes = seconds > 0 ? (seconds / 60).ceil() : (reading[item.id] ?? 0);
      if (minutes <= 0) continue;
      queue.add(WatchLaterEntry(id: item.id, title: item.title, minutes: minutes, isVideo: seconds > 0));
    }
    return queue;
  }

  /// Ровно год (два, три…) назад, иначе месяц, иначе неделю назад. Нечего вспомнить — null.
  Future<OnThisDay?> onThisDay(DateTime now) async {
    final items = (await _alive())..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    OnThisDay? found(List<Item> group, ReturnPeriod period, {int yearsAgo = 1}) => group.isEmpty
        ? null
        : OnThisDay(
            found: OnThisDayFound(period: period, yearsAgo: yearsAgo, count: group.length, firstId: group.first.id, firstTitle: group.first.title),
            ids: [for (final item in group) item.id],
          );

    // ближайший год с заметками: «год назад» теплее, чем «пять лет назад», но и пять лучше, чем ничего
    for (var years = 1; years <= 20; years++) {
      final day = DateTime(now.year - years, now.month, now.day);
      // 29 февраля бывает не каждый год
      if (day.month != now.month) continue;
      final group = [for (final item in items) if (_sameDay(item.createdAt, day)) item];
      if (group.isNotEmpty) return found(group, ReturnPeriod.year, yearsAgo: years);
    }
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    // 31 декабря месяц назад было 31 ноября — такого дня нет, месяц пропускается
    if (monthAgo.day == now.day) {
      final group = [for (final item in items) if (_sameDay(item.createdAt, monthAgo)) item];
      if (group.isNotEmpty) return found(group, ReturnPeriod.month);
    }
    final weekAgo = DateTime(now.year, now.month, now.day - 7);
    return found([for (final item in items) if (_sameDay(item.createdAt, weekAgo)) item], ReturnPeriod.week);
  }

  /// Сводка семи дней: сохранено, не открыто, без папки. Списки — свежие первыми.
  Future<WeekSummary> week(DateTime now) async {
    final since = now.subtract(const Duration(days: 7));
    final items = [for (final item in await _alive()) if (item.createdAt.isAfter(since)) item]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final unopened = [for (final item in items) if (item.openedAt == null) item.id];
    final unsorted = [for (final item in items) if (item.folderId == null) item.id];
    return WeekSummary(found: WeekFound(saved: items.length, unopened: unopened.length, unsorted: unsorted.length), unopened: unopened, unsorted: unsorted);
  }

  /// Что купить: заметки с тегом #купить и списки «Купить: …», где остались неотмеченные пункты.
  Future<List<ShoppingList>> shopping() async {
    final tagged = {
      for (final row in await _db
          .customSelect('SELECT item_tags.item_id AS id, tags.name AS name FROM item_tags JOIN tags ON tags.id = item_tags.tag_id', readsFrom: {_db.itemTags, _db.tags})
          .get())
        if (_shoppingTags.contains(normalizeTagName(row.read<String>('name')))) row.read<String>('id'),
    };
    final lists = <ShoppingList>[];
    for (final item in await _alive()) {
      final lines = [for (final line in item.body.split('\n')) if (checkLine.firstMatch(line) case final match?) (done: match.group(1) != ' ', text: match.group(2)!.trim())];
      final open = [for (final line in lines) if (!line.done) line.text];
      final byTag = tagged.contains(item.id);
      final byTitle = _shoppingTitle.hasMatch(item.title.trim());
      if (!byTag && !byTitle) continue;
      // список есть и весь отмечен — уже купили
      if (lines.isNotEmpty && open.isEmpty) continue;
      if (!byTag && open.isEmpty) continue;
      lists.add(ShoppingList(id: item.id, title: item.title, items: open));
    }
    return lists;
  }
}

/// Итог очереди для уведомления: сколько роликов, статей и минут.
WatchLaterFound summarizeWatchLater(List<WatchLaterEntry> queue) => WatchLaterFound(
  videos: queue.where((one) => one.isVideo).length,
  articles: queue.where((one) => !one.isVideo).length,
  minutes: queue.fold(0, (sum, one) => sum + one.minutes),
);
