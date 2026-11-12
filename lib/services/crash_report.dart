import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';

const _longestMessage = 160;
const _deepestStack = 50;

final _quoted = RegExp('"[^"]*"|\'[^\']*\'|«[^»]*»|„[^”]*”|“[^”]*”');
final _address = RegExp(r'[a-zA-Z][a-zA-Z0-9+.-]*://\S+');
final _withSlash = RegExp(r'\S*/\S*');
final _notLatin = RegExp(r'[^\x20-\x7E]+');
final _longNumber = RegExp(r'\d{5,}');
final _spaces = RegExp(r'\s+');

/// Вид ошибки: имя класса. Сам по себе ничего о заметках не говорит.
String crashType(Object error) => '${error.runtimeType}';

/// Текст ошибки для отчёта. Только у видов, где его пишет код, а не данные человека:
/// у остальных текста нет вовсе, один вид. И те вычищены: кавычки, пути, адреса, числа.
String? crashMessage(Object error) => switch (error) {
  // в кавычках здесь имена типов и методов, значения идут ниже первой строки
  TypeError() || NoSuchMethodError() => _tidy('$error', keepQuoted: true),
  // раньше AssertionError: FlutterError — её наследник
  FlutterError() => _tidy(error.message),
  RangeError() || StateError() || AssertionError() || UnsupportedError() || ConcurrentModificationError() || TimeoutException() => _tidy('$error'),
  FormatException() => _tidy(error.message),
  MissingPluginException() => _tidy(error.message ?? ''),
  PlatformException() => _tidy(error.code),
  FileSystemException() => _tidy(_withErrno(error.message, error.osError)),
  SocketException() => _tidy(_withErrno(error.message, error.osError)),
  TlsException() => _tidy(error.message),
  HttpException() => _tidy(error.message),
  http.ClientException() => _tidy(error.message),
  // ошибка базы: первая строка — что нарушено, запрос и его значения идут ниже
  _ when crashType(error) == 'SqliteException' => _tidy('$error'),
  _ => null,
};

String _withErrno(String message, OSError? system) => system == null ? message : '$message (errno ${system.errorCode})';

String? _tidy(String text, {bool keepQuoted = false}) {
  var line = text.split('\n').first;
  if (!keepQuoted) line = line.replaceAll(_quoted, "'...'");
  line = line.replaceAll(_address, '<url>').replaceAll(_withSlash, '<path>').replaceAll(_notLatin, ' ').replaceAll(_longNumber, '#').replaceAll(_spaces, ' ').trim();
  if (line.length > _longestMessage) line = line.substring(0, _longestMessage);
  return line.isEmpty ? null : line;
}

/// Кадры стека от места падения вглубь. Путь к файлу на диске не уходит: только имя.
List<CrashFrame> crashFrames(StackTrace stack) => [
  for (final frame in Trace.from(stack).frames.take(_deepestStack))
    CrashFrame(
      file: frame.uri.scheme == 'package' || frame.uri.scheme == 'dart' ? '${frame.uri}' : p.basename(frame.uri.path),
      function: frame.member ?? '',
      line: frame.line,
      column: frame.column,
    ),
];

class CrashFrame {
  const CrashFrame({required this.file, required this.function, this.line, this.column});

  factory CrashFrame.fromJson(Map<String, Object?> json) =>
      CrashFrame(file: json['file'] as String? ?? '', function: json['function'] as String? ?? '', line: json['line'] as int?, column: json['column'] as int?);

  /// Файл Dart (`package:stowa/…`) или класс Kotlin (`app.stowa.…`).
  final String file;
  final String function;
  final int? line;
  final int? column;

  bool get inApp => file.startsWith('package:stowa/') || file.startsWith('app.stowa.');

  Map<String, Object?> toJson() => {'file': file, 'function': function, 'line': ?line, 'column': ?column};
}

/// Одна ошибка, как она лежит на телефоне до отправки. Тот же вид пишет и Android
/// (`CrashCatcher.kt`): менять поля — в обоих местах.
class CrashRecord {
  const CrashRecord({
    required this.id,
    required this.at,
    required this.platform,
    required this.type,
    required this.frames,
    required this.window,
    this.message,
    this.fatal = false,
    this.library,
    this.release,
    this.environment,
    this.os,
    this.model,
    this.maker,
  });

  factory CrashRecord.fromJson(Map<String, Object?> json) => CrashRecord(
    id: json['id'] as String,
    at: DateTime.parse(json['at'] as String),
    platform: json['platform'] as String,
    type: json['type'] as String,
    message: json['message'] as String?,
    frames: [for (final frame in json['frames'] as List? ?? const []) CrashFrame.fromJson((frame as Map).cast())],
    window: json['window'] as String? ?? '',
    fatal: json['fatal'] as bool? ?? false,
    library: json['library'] as String?,
    release: json['release'] as String?,
    environment: json['environment'] as String?,
    os: json['os'] as String?,
    model: json['model'] as String?,
    maker: json['maker'] as String?,
  );

  /// 32 шестнадцатеричных знака: по нему сервер узнаёт повторную отправку.
  final String id;
  final DateTime at;

  /// `dart` или `java`.
  final String platform;
  final String type;
  final String? message;
  final List<CrashFrame> frames;

  /// Откуда: `main`, `share`, `quick`, `background` или `android`.
  final String window;

  /// Процесс упал. Ошибка Dart приложение не роняет, падение — это Android.
  final bool fatal;

  /// Часть Flutter, поймавшая ошибку: «widgets library», «rendering library».
  final String? library;
  final String? release;
  final String? environment;
  final String? os;
  final String? model;
  final String? maker;

  /// Одинаковые ошибки за запуск записываются один раз: вид и верхний кадр своего кода.
  String get fingerprint {
    final top = frames.where((frame) => frame.inApp).firstOrNull ?? frames.firstOrNull;
    return top == null ? type : '$type@${top.file}:${top.function}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'platform': platform,
    'type': type,
    'message': ?message,
    'frames': [for (final frame in frames) frame.toJson()],
    'window': window,
    'fatal': fatal,
    'library': ?library,
    'release': ?release,
    'environment': ?environment,
    'os': ?os,
    'model': ?model,
    'maker': ?maker,
  };

  /// Событие в виде, который принимает Bugsink (формат Sentry): кадры от старого к новому.
  Map<String, Object?> toEvent() => {
    'event_id': id,
    'timestamp': at.toUtc().toIso8601String(),
    'platform': platform,
    'level': fatal ? 'fatal' : 'error',
    'release': ?release,
    'environment': ?environment,
    'exception': {
      'values': [
        {
          'type': type,
          'value': message ?? '',
          'mechanism': {'type': 'generic', 'handled': !fatal},
          'stacktrace': {
            'frames': [
              for (final frame in frames.reversed) {'filename': frame.file, 'function': frame.function, 'lineno': ?frame.line, 'colno': ?frame.column, 'in_app': frame.inApp},
            ],
          },
        },
      ],
    },
    'contexts': {
      if (os != null) 'os': {'name': 'Android', 'version': os},
      if (model != null || maker != null) 'device': {'model': ?model, 'manufacturer': ?maker},
    },
    'tags': {'window': window, 'library': ?library},
  };
}
