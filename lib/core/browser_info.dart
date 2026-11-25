import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Браузер словами: «Chrome», «Firefox».
String browserLabel(BrowserName name) => switch (name) {
  BrowserName.chrome => 'Chrome',
  BrowserName.firefox => 'Firefox',
  BrowserName.safari => 'Safari',
  BrowserName.edge => 'Edge',
  BrowserName.opera => 'Opera',
  BrowserName.samsungInternet => 'Samsung Internet',
  BrowserName.msie => 'Internet Explorer',
  BrowserName.unknown => 'Browser',
};

// номер версии в строке браузера: у каждого своя метка
final _versionMarks = {
  BrowserName.edge: RegExp(r'Edg/(\d+)'),
  BrowserName.opera: RegExp(r'OPR/(\d+)'),
  BrowserName.samsungInternet: RegExp(r'SamsungBrowser/(\d+)'),
  BrowserName.firefox: RegExp(r'Firefox/(\d+)'),
  BrowserName.chrome: RegExp(r'Chrome/(\d+)'),
  BrowserName.safari: RegExp(r'Version/(\d+)'),
};

/// Главный номер версии браузера из строки браузера: «131». Не нашёлся — пусто.
String browserVersion(BrowserName name, String agent) => _versionMarks[name]?.firstMatch(agent)?.group(1) ?? '';

/// Система под браузером: «Windows», «macOS», «Linux», «Android», «iOS».
String browserSystem(String platform, String agent) {
  if (agent.contains('Android')) return 'Android';
  if (RegExp('iPhone|iPad|iPod').hasMatch(agent)) return 'iOS';
  if (platform.startsWith('Win') || agent.contains('Windows')) return 'Windows';
  if (platform.startsWith('Mac') || agent.contains('Mac OS')) return 'macOS';
  if (agent.contains('CrOS')) return 'ChromeOS';
  if (platform.contains('Linux') || agent.contains('Linux')) return 'Linux';
  return 'Web';
}

/// Имя устройства в истории версий и журнале правок: «Chrome, Linux».
Future<String> browserDeviceName() async {
  try {
    final info = await DeviceInfoPlugin().webBrowserInfo;
    return '${browserLabel(info.browserName)}, ${browserSystem(info.platform ?? '', info.userAgent ?? '')}';
  } on Object {
    return '';
  }
}

/// Сайт о себе для отчёта об ошибке — то, что телефон кладёт файлом `about.json`:
/// версия Stowa, система и браузер с главным номером версии.
Future<Map<String, Object?>> browserAbout() async {
  try {
    final package = await PackageInfo.fromPlatform();
    final info = await DeviceInfoPlugin().webBrowserInfo;
    final agent = info.userAgent ?? '';
    final version = browserVersion(info.browserName, agent);
    return {
      'release': 'app.stowa@${package.version}+${package.buildNumber}',
      'os_name': browserSystem(info.platform ?? '', agent),
      'model': version.isEmpty ? browserLabel(info.browserName) : '${browserLabel(info.browserName)} $version',
    };
  } on Object {
    return const {};
  }
}
