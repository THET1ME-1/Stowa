import 'dart:io';

import 'package:drift/drift.dart';

/// В браузере базы в памяти и из файла нет: копия из браузера идёт без снимка
/// базы, указатель собирается из файлов.
QueryExecutor memoryExecutor() => throw UnsupportedError('База в памяти в браузере не открывается');

QueryExecutor fileExecutor(File file) => throw UnsupportedError('База из файла в браузере не открывается');
