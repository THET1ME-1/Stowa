import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:stowa/services/crash_reporter.dart';

void main() {
  late Directory folder;
  var enabled = true;
  var now = DateTime.utc(2026, 11, 12, 10);

  setUp(() {
    folder = Directory.systemTemp.createTempSync('stowa_crashes');
    enabled = true;
    now = DateTime.utc(2026, 11, 12, 10);
  });
  tearDown(() => folder.deleteSync(recursive: true));

  CrashReporter reporter({String window = 'main'}) => CrashReporter(folder: folder, window: window, enabled: () => enabled, clock: () => now);

  StackTrace stackAt(String function) => StackTrace.fromString('#0      $function (package:stowa/services/a.dart:10:3)\n#1      main (package:stowa/main.dart:5:1)');

  List<File> waiting() => [
    for (final file in folder.listSync().whereType<File>())
      if (p.basename(file.path) != 'about.json') file,
  ];

  Map<String, Object?> read(File file) => jsonDecode(file.readAsStringSync()) as Map<String, Object?>;

  void about() => File(p.join(folder.path, 'about.json')).writeAsStringSync(jsonEncode({'release': 'app.stowa@0.2.0+4', 'os': '14', 'model': 'Pixel 7', 'maker': 'Google'}));

  test('ошибка ложится в файл: вид, место, окно, версия и телефон', () {
    about();
    reporter(window: 'quick').record(StateError('No element'), stackAt('LineDock.save'), library: 'widgets library');
    final record = read(waiting().single);
    expect(record['type'], 'StateError');
    expect(record['message'], 'Bad state: No element');
    expect(record['window'], 'quick');
    expect(record['library'], 'widgets library');
    expect(record['release'], 'app.stowa@0.2.0+4');
    expect(record['model'], 'Pixel 7');
    expect(record['at'], '2026-11-12T10:00:00.000Z');
    expect(((record['frames'] as List).first as Map)['function'], 'LineDock.save');
  });

  test('текст незнакомой ошибки в файл не попадает', () {
    reporter().record(Exception('заметка Пароли от банка'), stackAt('save'));
    expect(waiting().single.readAsStringSync(), isNot(contains('Пароли')));
  });

  test('выключено: ничего не пишется, накопленное стирается', () {
    reporter().record(StateError('a'), stackAt('first'));
    expect(waiting(), hasLength(1));
    enabled = false;
    reporter().record(StateError('b'), stackAt('second'));
    expect(waiting(), isEmpty);
  });

  test('одна и та же ошибка за запуск записывается один раз', () {
    final crashes = reporter();
    crashes.record(StateError('a'), stackAt('save'));
    crashes.record(StateError('b'), stackAt('save'));
    expect(waiting(), hasLength(1));
  });

  test('за запуск не больше десяти записей', () {
    final crashes = reporter();
    for (var i = 0; i < 30; i++) {
      crashes.record(StateError('a'), stackAt('step$i'));
    }
    expect(waiting(), hasLength(10));
  });

  test('в очереди не больше двадцати файлов: старые уступают место', () {
    for (var i = 0; i < 25; i++) {
      now = DateTime.utc(2026, 11, 1 + i);
      reporter().record(StateError('a'), stackAt('step$i'));
    }
    final functions = [for (final file in waiting()) ((read(file)['frames'] as List).first as Map)['function']];
    expect(functions, hasLength(20));
    expect(functions, isNot(contains('step0')));
    expect(functions, contains('step24'));
  });

  test('ошибка при записи не роняет приложение', () {
    final crashes = reporter();
    folder.deleteSync(recursive: true);
    File(folder.path).writeAsStringSync('на месте папки лежит файл');
    expect(() => crashes.record(StateError('a'), stackAt('save')), returnsNormally);
    File(folder.path).deleteSync();
    folder.createSync();
  });

  group('перехват', () {
    late FlutterExceptionHandler? flutterBefore;
    late ErrorCallback? platformBefore;

    setUp(() {
      flutterBefore = FlutterError.onError;
      platformBefore = PlatformDispatcher.instance.onError;
    });
    tearDown(() {
      FlutterError.onError = flutterBefore;
      PlatformDispatcher.instance.onError = platformBefore;
    });

    test('ошибка из Flutter записывается и идёт дальше прежнему обработчику', () {
      final passed = <FlutterErrorDetails>[];
      FlutterError.onError = passed.add;
      reporter().attach();
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('No element'), stack: stackAt('build'), library: 'widgets library'));
      expect(read(waiting().single)['library'], 'widgets library');
      expect(passed, hasLength(1));
    });

    test('тихая ошибка Flutter не записывается', () {
      FlutterError.onError = (_) {};
      reporter().attach();
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('a'), stack: stackAt('build'), silent: true));
      expect(waiting(), isEmpty);
    });

    test('ошибка мимо Flutter записывается, ответ прежнего обработчика сохраняется', () {
      PlatformDispatcher.instance.onError = (_, _) => true;
      reporter().attach();
      expect(PlatformDispatcher.instance.onError!(StateError('a'), stackAt('later')), isTrue);
      expect(read(waiting().single)['type'], 'StateError');
    });
  });

  group('отправка', () {
    late List<http.Request> requests;
    var status = 200;

    setUp(() {
      requests = [];
      status = 200;
    });

    MockClient client() => MockClient((request) async {
      requests.add(request);
      return http.Response('{}', status);
    });

    test('принятое событие уходит одним конвертом и стирается с телефона', () async {
      about();
      reporter().record(StateError('No element'), stackAt('save'));
      final id = read(waiting().single)['id'];
      await reporter().send(client());
      final request = requests.single;
      expect('${request.url}', 'https://bugsink.togetherly.day/api/3/envelope/');
      expect(request.headers['X-Sentry-Auth'], contains('sentry_key=c94514b828594315be1f835d37f7e340'));
      expect(request.headers['Content-Type'], startsWith('application/x-sentry-envelope'));
      final lines = const LineSplitter().convert(request.body);
      expect(lines, hasLength(3));
      expect((jsonDecode(lines[0]) as Map)['event_id'], id);
      expect((jsonDecode(lines[1]) as Map)['type'], 'event');
      expect((jsonDecode(lines[1]) as Map)['length'], utf8.encode(lines[2]).length);
      final event = jsonDecode(lines[2]) as Map;
      expect(event['event_id'], id);
      expect(event['release'], 'app.stowa@0.2.0+4');
      expect(waiting(), isEmpty);
    });

    test('сервер недоступен: запись ждёт, очередь дальше не идёт', () async {
      final crashes = reporter();
      crashes.record(StateError('a'), stackAt('first'));
      crashes.record(StateError('a'), stackAt('second'));
      status = 503;
      await crashes.send(client());
      expect(requests, hasLength(1));
      expect(waiting(), hasLength(2));
    });

    test('нет сети: запись ждёт', () async {
      reporter().record(StateError('a'), stackAt('save'));
      await reporter().send(MockClient((_) async => throw const SocketException('нет сети')));
      expect(waiting(), hasLength(1));
    });

    test('сервер отверг запись: она стирается, очередь идёт дальше', () async {
      final crashes = reporter();
      crashes.record(StateError('a'), stackAt('first'));
      crashes.record(StateError('a'), stackAt('second'));
      status = 400;
      await crashes.send(client());
      expect(requests, hasLength(2));
      expect(waiting(), isEmpty);
    });

    test('битый файл стирается без запроса', () async {
      File(p.join(folder.path, 'broken.json')).writeAsStringSync('{не json');
      await reporter().send(client());
      expect(requests, isEmpty);
      expect(waiting(), isEmpty);
    });

    test('выключено: ничего не уходит, накопленное стирается', () async {
      reporter().record(StateError('a'), stackAt('save'));
      enabled = false;
      await reporter().send(client());
      expect(requests, isEmpty);
      expect(waiting(), isEmpty);
    });

    test('запись от Android уходит как есть', () async {
      File(p.join(folder.path, 'native.json')).writeAsStringSync(
        jsonEncode({
          'id': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'at': '2026-11-12T09:00:00.000Z',
          'platform': 'java',
          'type': 'java.lang.IllegalStateException',
          'frames': [
            {'file': 'app.stowa.MainActivity', 'function': 'onCreate', 'line': 42},
          ],
          'window': 'android',
          'fatal': true,
          'release': 'app.stowa@0.2.0+4',
          'environment': 'production',
          'os': '14',
          'model': 'Pixel 7',
          'maker': 'Google',
        }),
      );
      await reporter().send(client());
      final event = jsonDecode(const LineSplitter().convert(requests.single.body)[2]) as Map;
      expect(event['platform'], 'java');
      expect(event['level'], 'fatal');
      final value = ((event['exception'] as Map)['values'] as List).single as Map;
      expect(value['type'], 'java.lang.IllegalStateException');
      expect((((value['stacktrace'] as Map)['frames'] as List).single as Map)['in_app'], isTrue);
    });
  });
}
