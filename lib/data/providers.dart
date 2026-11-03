import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/folder_guess.dart';
import '../services/capture_service.dart';
import '../services/reminder_service.dart';
import 'db/database.dart';
import 'repositories/folders_repository.dart';
import 'repositories/items_repository.dart';
import 'repositories/rules_repository.dart';
import 'repositories/tags_repository.dart';

/// База и папка файлов открываются в main и подставляются сюда.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('база открывается в main'));
final filesRootProvider = Provider<Directory>((ref) => throw UnimplementedError('папка файлов задаётся в main'));

/// Часы: в тестах подменяются, чтобы «завтра» было предсказуемым.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final itemsRepositoryProvider = Provider((ref) => ItemsRepository(ref.watch(databaseProvider)));
final foldersRepositoryProvider = Provider((ref) => FoldersRepository(ref.watch(databaseProvider)));
final tagsRepositoryProvider = Provider((ref) => TagsRepository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)));

final captureServiceProvider = Provider(
  (ref) => CaptureService(
    ref.watch(databaseProvider),
    tags: ref.watch(tagsRepositoryProvider),
    filesRoot: ref.watch(filesRootProvider),
    clock: ref.watch(clockProvider),
  ),
);

final recentItemsProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchRecent());

/// Ближайшие напоминания с момента подписки. Главная перечитывает их,
/// когда приложение возвращается на экран.
final upcomingProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchUpcoming(ref.watch(clockProvider)()));

final foldersProvider = StreamProvider((ref) => ref.watch(foldersRepositoryProvider).watchAll());
final pinnedTagsProvider = StreamProvider((ref) => ref.watch(tagsRepositoryProvider).watchPinned());
final allTagsProvider = StreamProvider((ref) => ref.watch(tagsRepositoryProvider).watchAll());

/// Угадыватель папки по тому, что уже разложено. Пересобирается вместе с базой.
final folderIndexProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchFolderDocs().map(FolderIndex.new));

final rulesRepositoryProvider = Provider((ref) => RulesRepository(ref.watch(databaseProvider)));
final rulesProvider = StreamProvider((ref) => ref.watch(rulesRepositoryProvider).watchEnabled());

/// Одна вещь целиком для её страницы, обновляется вместе с базой.
final itemProvider = StreamProvider.family<ItemFull?, String>((ref, id) => ref.watch(itemsRepositoryProvider).watchItem(id));

/// Система уведомлений: настоящая подставляется в main, в тестах — тишина.
final notificationPortProvider = Provider<NotificationPort>((ref) => const SilentNotificationPort());
final reminderServiceProvider = Provider((ref) => ReminderService(ref.watch(notificationPortProvider)));
final remindersProvider = StreamProvider((ref) => ref.watch(itemsRepositoryProvider).watchReminders());

/// Вещи папки; null — всё, что лежит без папки.
final folderItemsProvider = StreamProvider.family<List<ItemCard>, String?>((ref, folderId) => ref.watch(itemsRepositoryProvider).watchFolder(folderId));
