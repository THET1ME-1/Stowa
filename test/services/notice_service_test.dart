import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/data/db/database.dart';
import 'package:stowa/data/repositories/items_repository.dart';
import 'package:stowa/domain/models.dart';
import 'package:stowa/services/notice_service.dart';
import 'package:stowa/services/reminder_actions.dart';
import 'package:stowa/services/reminder_service.dart';

// идея тестировщицы 16.11: «маркер, который висит сверху телефона, пока сам не снимешь» —
// заметка «Закреплена в уведомлениях»: тихое уведомление, видно в строке состояния и на
// экране блокировки, снимается кнопкой «Убрать»
class _Port implements NotificationPort {
  final shown = <int, ({String title, String body, String payload, bool private})>{};
  var showCalls = 0;

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({required int id, required String title, required String body, required DateTime at, required String payload}) async {}

  @override
  Future<void> show({required int id, required String title, required String body, required String payload}) async {}

  @override
  Future<void> showPinned({required int id, required String title, required String body, required String payload, required bool private}) async {
    showCalls++;
    shown[id] = (title: title, body: body, payload: payload, private: private);
  }

  @override
  Future<void> cancel(int id) async => shown.remove(id);

  @override
  Future<List<int>> activePinned() async => [...shown.keys];
}

void main() {
  late AppDatabase db;
  late ItemsRepository items;
  late _Port port;
  final now = DateTime(2026, 11, 16, 21);

  setUp(() {
    db = AppDatabase.memory();
    items = ItemsRepository(db, clock: () => now);
    port = _Port();
  });
  tearDown(() => db.close());

  Future<void> note(String id, String title, String body, {String? folder}) => db
      .into(db.items)
      .insert(ItemsCompanion.insert(id: id, kind: ItemKind.note, title: title, body: Value(body), folderId: Value(folder), createdAt: now, updatedAt: now));

  test('закрепил — признак в базе, время правки не двигается; убрал — признака нет', () async {
    await note('a', 'Сказать маме', 'Сказать маме\nпро субботу');
    await items.setNoticed('a', true);
    final row = await (db.select(db.items)..where((t) => t.id.equals('a'))).getSingle();
    expect(row.noticeAt, now);
    expect(row.updatedAt, now);
    await items.setNoticed('a', false);
    expect((await (db.select(db.items)..where((t) => t.id.equals('a'))).getSingle()).noticeAt, isNull);
  });

  test('список закреплённых: текст под заголовком; скрытая папка — без текста; корзина — нет', () async {
    await db.into(db.folders).insert(FoldersCompanion.insert(id: 'h', name: 'Тайное', icon: 'folder', shape: 'pill', hidden: const Value(true)));
    await note('a', 'Сказать маме', 'Сказать маме\nпро субботу');
    await note('b', 'Пароль', 'Пароль\n1234', folder: 'h');
    await note('c', 'Старое', 'Старое');
    for (final id in ['a', 'b', 'c']) {
      await items.setNoticed(id, true);
    }
    await (db.update(db.items)..where((t) => t.id.equals('c'))).write(ItemsCompanion(deletedAt: Value(now)));
    final list = await items.watchNotices(hiddenTitle: 'Закреплённая заметка').first;
    expect({for (final one in list) one.id: (one.title, one.body)}, {
      'a': ('Сказать маме', 'про субботу'),
      'hidden:b': ('Закреплённая заметка', ''),
    });
  });

  test('служба: каждой заметке своё уведомление, убранное снимается, неизменное не трогается', () async {
    final service = NoticeService(port);
    await service.sync(const [(id: 'a', title: 'Сказать маме', body: 'про субботу'), (id: 'b', title: 'Купить', body: '')], private: false);
    expect(port.shown.values.map((one) => one.title).toSet(), {'Сказать маме', 'Купить'});
    expect(port.shown[noticeNotificationId('a')]!.payload, 'a');
    // не совпадает с номером напоминания той же заметки: оба уведомления живут
    expect(noticeNotificationId('a'), isNot(notificationId('a')));
    final calls = port.showCalls;
    await service.sync(const [(id: 'a', title: 'Сказать маме', body: 'про субботу')], private: false);
    expect(port.shown.keys, [noticeNotificationId('a')]);
    expect(port.showCalls, calls);
    // смахнули — при возврате в приложение и в фоне показывается снова
    port.shown.clear();
    await service.sync(const [(id: 'a', title: 'Сказать маме', body: 'про субботу')], private: false, force: true);
    expect(port.shown, hasLength(1));
  });

  test('висящее от прошлого запуска (заметку удалили, пока Stowa была закрыта) — снимается', () async {
    // уведомление осталось от прошлого процесса: в памяти новой службы его нет
    port.shown[noticeNotificationId('gone')] = (title: 'Удалённая', body: '', payload: 'gone', private: false);
    await NoticeService(port).sync(const [(id: 'a', title: 'Сказать маме', body: '')], private: false);
    expect(port.shown.keys, [noticeNotificationId('a')]);
  });

  test('«Код на вход» — на экране блокировки без текста', () async {
    await NoticeService(port).sync(const [(id: 'a', title: 'Сказать маме', body: '')], private: true);
    expect(port.shown.values.single.private, isTrue);
  });

  test('кнопка «Убрать» снимает признак, даже когда приложение закрыто', () async {
    await note('a', 'Сказать маме', 'Сказать маме');
    await items.setNoticed('a', true);
    await handleReminderAction(items, actionId: noticeRemove, itemId: 'a', now: now);
    expect((await (db.select(db.items)..where((t) => t.id.equals('a'))).getSingle()).noticeAt, isNull);
  });
}
