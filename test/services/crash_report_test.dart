import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stowa/services/crash_report.dart';

/// Тёзка исключения базы: отчёт узнаёт его по имени, без зависимости от sqlite3.
class SqliteException implements Exception {
  @override
  String toString() => 'SqliteException(1555): while executing statement, UNIQUE constraint failed: items.id (code 1555)\n  Causing statement: INSERT INTO items VALUES (?), parameters: Купить молоко';
}

Object caught(void Function() body) {
  try {
    body();
  } catch (error) {
    return error;
  }
  throw StateError('ничего не упало');
}

void main() {
  group('что уходит из текста ошибки', () {
    test('незнакомая ошибка — только вид, без текста', () {
      final error = Exception('заметка «Пароли» https://bank.md/login?token=abc');
      expect(crashType(error), '_Exception');
      expect(crashMessage(error), isNull);
    });

    test('несовпадение типов: типы в кавычках остаются', () {
      final dynamic nothing = null;
      final error = caught(() => nothing as String);
      expect(crashMessage(error), contains("type 'Null' is not a subtype of type 'String'"));
    });

    test('вызов на null: одна строка, без получателя и аргументов', () {
      final dynamic nothing = null;
      final message = crashMessage(caught(() => nothing.openNote('Дневник')))!;
      expect(message, contains('openNote'));
      expect(message, isNot(contains('Receiver')));
      expect(message, isNot(contains('Дневник')));
      expect(message, isNot(contains('\n')));
    });

    test('StateError: слова из кода остаются', () {
      expect(crashMessage(StateError('No element')), 'Bad state: No element');
    });

    test('кавычки, пути, адреса, не-латиница и длинные числа вычищаются', () {
      final message = crashMessage(StateError('no file "/storage/emulated/0/Stowa/Diary.md" for \'Mama\' id 1234567 at https://my.home/x Привет'))!;
      expect(message, isNot(contains('Diary')));
      expect(message, isNot(contains('Mama')));
      expect(message, isNot(contains('1234567')));
      expect(message, isNot(contains('my.home')));
      expect(message, isNot(contains('Привет')));
      expect(message, startsWith('Bad state: no file'));
    });

    test('путь и адрес без кавычек заменяются метками', () {
      final message = crashMessage(StateError('cannot read /data/user/0/app.stowa/files/a.md from http://192.168.1.5:8080/v1'))!;
      expect(message, 'Bad state: cannot read <path> from <url>');
    });

    test('ошибка файла: текст и номер ошибки системы, без пути', () {
      const error = FileSystemException('Cannot open file', '/storage/emulated/0/Stowa/Пароли.md', OSError('No such file or directory', 2));
      expect(crashMessage(error), 'Cannot open file (errno 2)');
    });

    test('ошибка сети: без адреса сервера', () {
      const error = SocketException("Failed host lookup: 'my.server.home'", osError: OSError('No address associated with hostname', 7));
      final message = crashMessage(error)!;
      expect(message, isNot(contains('my.server.home')));
      expect(message, endsWith('(errno 7)'));
    });

    test('ошибка клиента сети: без адреса запроса', () {
      final error = http.ClientException('Connection closed while receiving data from https://api.example.com/v1?key=abc', Uri.parse('https://api.example.com/v1?key=abc'));
      final message = crashMessage(error)!;
      expect(message, isNot(contains('example.com')));
      expect(message, startsWith('Connection closed while receiving data'));
    });

    test('ошибка канала: только код', () {
      expect(crashMessage(PlatformException(code: 'channel-error', message: 'файл /sdcard/a.md', details: 'ещё')), 'channel-error');
    });

    test('ошибка базы: без запроса и его значений', () {
      final message = crashMessage(SqliteException())!;
      expect(message, contains('UNIQUE constraint failed: items.id'));
      expect(message, isNot(contains('INSERT')));
      expect(message, isNot(contains('молоко')));
    });

    test('ошибка Flutter: первая строка', () {
      expect(crashMessage(FlutterError('A RenderFlex overflowed by 12 pixels on the bottom.\nThe relevant widget was Column')), 'A RenderFlex overflowed by 12 pixels on the bottom.');
    });

    test('длинный текст обрезается', () {
      expect(crashMessage(StateError('a' * 500))!.length, lessThanOrEqualTo(160));
    });
  });

  group('стек', () {
    final stack = StackTrace.fromString(
      '#0      CaptureService.save (package:stowa/services/capture_service.dart:120:7)\n'
      '#1      _rootRunUnary (dart:async/zone.dart:1538:47)\n'
      '<asynchronous suspension>\n'
      '#2      main (file:///home/someone/secret/main.dart:5:3)\n',
    );

    test('кадры от места падения, с файлом, функцией и строкой', () {
      final frames = crashFrames(stack);
      expect(frames.first.file, 'package:stowa/services/capture_service.dart');
      expect(frames.first.function, 'CaptureService.save');
      expect(frames.first.line, 120);
      expect(frames.first.column, 7);
      expect(frames.first.inApp, isTrue);
      expect(frames.firstWhere((frame) => frame.function == '_rootRunUnary').inApp, isFalse);
    });

    test('путь к файлу на диске не уходит: только имя', () {
      expect(crashFrames(stack).last.file, 'main.dart');
    });

    test('длинный стек обрезается', () {
      final deep = StackTrace.fromString([for (var i = 0; i < 200; i++) '#$i      step$i (package:stowa/a.dart:$i:1)'].join('\n'));
      expect(crashFrames(deep).length, lessThanOrEqualTo(50));
      expect(crashFrames(deep).first.function, 'step0');
    });
  });

  group('запись', () {
    CrashRecord record({bool fatal = false}) => CrashRecord(
      id: '0123456789abcdef0123456789abcdef',
      at: DateTime.utc(2026, 11, 12, 10, 30),
      platform: 'dart',
      type: 'StateError',
      message: 'Bad state: No element',
      frames: const [
        CrashFrame(file: 'package:stowa/a.dart', function: 'top', line: 3, column: 1),
        CrashFrame(file: 'dart:async/zone.dart', function: 'bottom', line: 9),
      ],
      window: 'quick',
      fatal: fatal,
      library: 'widgets library',
      release: 'app.stowa@0.2.0+4',
      environment: 'production',
      os: '14',
      model: 'Pixel 7',
      maker: 'Google',
    );

    test('переживает запись в файл и чтение обратно', () {
      final back = CrashRecord.fromJson(record().toJson());
      expect(back.toJson(), record().toJson());
      expect(back.frames.first.function, 'top');
    });

    test('отпечаток: вид ошибки и верхний кадр своего кода', () {
      expect(record().fingerprint, 'StateError@package:stowa/a.dart:top');
    });

    test('событие для сервера: ошибка, стек от старого к новому, версия, телефон, окно', () {
      final event = record().toEvent();
      expect(event['event_id'], '0123456789abcdef0123456789abcdef');
      expect(event['timestamp'], '2026-11-12T10:30:00.000Z');
      expect(event['platform'], 'dart');
      expect(event['level'], 'error');
      expect(event['release'], 'app.stowa@0.2.0+4');
      expect(event['environment'], 'production');
      final value = ((event['exception'] as Map)['values'] as List).single as Map;
      expect(value['type'], 'StateError');
      expect(value['value'], 'Bad state: No element');
      final frames = (value['stacktrace'] as Map)['frames'] as List;
      expect((frames.last as Map)['function'], 'top');
      expect((frames.last as Map)['in_app'], isTrue);
      expect((frames.first as Map)['in_app'], isFalse);
      expect(event['contexts'], {
        'os': {'name': 'Android', 'version': '14'},
        'device': {'model': 'Pixel 7', 'manufacturer': 'Google'},
      });
      expect(event['tags'], {'window': 'quick', 'library': 'widgets library'});
    });

    test('падение процесса помечено как fatal и необработанное', () {
      final event = record(fatal: true).toEvent();
      expect(event['level'], 'fatal');
      final value = ((event['exception'] as Map)['values'] as List).single as Map;
      expect((value['mechanism'] as Map)['handled'], isFalse);
    });
  });
}
