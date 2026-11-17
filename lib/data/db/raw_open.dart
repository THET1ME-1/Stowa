import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// База в памяти (тесты) и база из файла (снимок в резервной копии). В браузере
/// вместо этого файла — `raw_open_web.dart`: нативный SQLite туда не собирается.
QueryExecutor memoryExecutor() => NativeDatabase.memory();

QueryExecutor fileExecutor(File file) => NativeDatabase(file);
