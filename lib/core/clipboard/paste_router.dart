import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Что делать со вставленными файлами (картинка из буфера, файл из проводника).
typedef PasteHandler = Future<void> Function(List<XFile> files);

// так браузер зовёт любую картинку из буфера: снимок экрана, «Копировать картинку»
final _clipboardImage = RegExp(r'^image\.\w+$', caseSensitive: false);

/// Имя вставленного файла. Картинка без своего имени («image.png» браузера) называется по
/// дате, как фото камеры: подпись у заметки тогда «Фото от …», а не «Image», и вставки в
/// одну заметку не спорят за одно имя. Файл с настоящим именем остаётся под своим.
String pastedFileName(String name, String mime, DateTime at) {
  final trimmed = name.trim();
  if (!mime.startsWith('image/') || (trimmed.isNotEmpty && !_clipboardImage.hasMatch(trimmed))) return name;
  final dot = trimmed.lastIndexOf('.');
  final extension = dot > 0 ? trimmed.substring(dot + 1).toLowerCase() : (mime == 'image/jpeg' ? 'jpg' : mime.substring('image/'.length));
  String two(int value) => value.toString().padLeft(2, '0');
  return 'IMG-${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}${two(at.second)}.$extension';
}

/// Место видно человеку: его экран сверху (не закрыт другим экраном или окном) и вкладка
/// не спрятана — у спрятанной вкладки рабочего пространства часы выключены.
bool shownOnScreen(State state) {
  if (!state.mounted) return false;
  final context = state.context;
  return (ModalRoute.of(context)?.isCurrent ?? true) && TickerMode.valuesOf(context).enabled;
}

/// Куда идёт вставка из буфера. Получает место, где человек работал последним: текст
/// заметки, где стоит курсор, холст, которого коснулись, строка в фокусе. Места заявляют
/// себя сами ([claim]) при касании и фокусе и уходят при закрытии ([release]). Если ни одного
/// нет — запасное место ([fallback]): строка «Закинь что угодно».
class PasteRouter {
  // порядок вставки — порядок работы: последнее — нынешнее
  final _active = <Object, _Place>{};
  final _fallback = <Object, _Place>{};

  /// [owner] — место, где сейчас работают: вставка идёт в него. [shown] — видно ли место
  /// сейчас: закрытое другим окном или спрятанной вкладкой уступает предыдущему.
  void claim(Object owner, PasteHandler handler, {bool Function()? shown}) {
    _active.remove(owner);
    _active[owner] = (handler: handler, shown: shown);
  }

  /// [owner] принимает вставку, когда других мест нет или их не видно.
  void fallback(Object owner, PasteHandler handler, {bool Function()? shown}) {
    _fallback.remove(owner);
    _fallback[owner] = (handler: handler, shown: shown);
  }

  void release(Object owner) {
    _active.remove(owner);
    _fallback.remove(owner);
  }

  /// Отдать файлы нынешнему месту. false — отдавать некому или нечего.
  Future<bool> deliver(List<XFile> files) async {
    if (files.isEmpty) return false;
    final places = [..._active.values.toList().reversed, ..._fallback.values.toList().reversed];
    for (final place in places) {
      if (!(place.shown?.call() ?? true)) continue;
      await place.handler(files);
      return true;
    }
    return false;
  }
}

typedef _Place = ({PasteHandler handler, bool Function()? shown});
