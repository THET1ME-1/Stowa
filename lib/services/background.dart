import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/icons/icon_registry.dart';
import '../data/db/database.dart';
import '../data/settings_repository.dart';
import 'ai_image.dart';
import 'ai_worker.dart';

const _aiTask = 'stowa-ai-queue';

/// Раз в 15 минут при наличии сети система будит приложение и разбирает очередь ИИ,
/// даже если его давно не открывали.
Future<void> scheduleBackgroundWork() async {
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _aiTask,
    _aiTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final settings = SettingsRepository(await SharedPreferences.getInstance(), const SecureKeyStore());
    if (!settings.ai.active) return true;
    // база общая с открытым приложением, если оно сейчас живо
    final db = AppDatabase();
    final client = http.Client();
    try {
      await AiWorker(
        db,
        settings: settings,
        http: client,
        clock: DateTime.now,
        timeZone: (await FlutterTimezone.getLocalTimezone()).identifier,
        filesRoot: await getApplicationSupportDirectory(),
        imageForAi: imageForAi,
        isIcon: hasSymbol,
      ).drain();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close();
      await db.close();
    }
  });
}
