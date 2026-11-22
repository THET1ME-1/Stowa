import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Просьба переключить заметку между просмотром и правкой (Ctrl+E на мониторе). [serial]
/// растёт на каждую: та же заметка второй раз подряд — тоже новая просьба.
class EditToggleRequest {
  const EditToggleRequest(this.itemId, this.serial);

  final String itemId;
  final int serial;
}

/// Страница заметки слушает и переключает правку у себя: рабочее пространство знает только,
/// какая заметка открыта, а поля и сохранение — её.
final editToggleProvider = NotifierProvider<EditToggle, EditToggleRequest?>(EditToggle.new);

class EditToggle extends Notifier<EditToggleRequest?> {
  @override
  EditToggleRequest? build() => null;

  void toggle(String itemId) => state = EditToggleRequest(itemId, (state?.serial ?? 0) + 1);
}
