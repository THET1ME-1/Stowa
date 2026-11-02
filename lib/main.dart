import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // вложения лежат рядом с базой, в базе — пути от этой папки
  final filesRoot = await getApplicationSupportDirectory();
  runApp(
    ProviderScope(overrides: [databaseProvider.overrideWithValue(AppDatabase()), filesRootProvider.overrideWithValue(filesRoot)], child: const StowaApp()),
  );
}
