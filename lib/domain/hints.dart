/// Знакомство с приложением и подсказки по месту: только правила, без хранения.
/// Описание — `docs/specs/2026-11-16-onboarding-design.md`.
library;

/// Шаги знакомства над строкой главной, по порядку. [finish] — последняя карточка «знакомство закончено».
enum StartStep { stow, search, remind, folder, tag, commands, finish }

/// Что человек сделал строкой: этим шаги засчитываются.
enum StartEvent { stowed, found, reminded, foldered, tagged, commanded }

/// Подсказки по месту, по одной на экран.
enum Tip { noteBar, longPress, catalog, folderMenu, sort, canvas, base, aiKey, edge }

/// Действие, которое делает шаг.
const _eventOf = {
  StartStep.stow: StartEvent.stowed,
  StartStep.search: StartEvent.found,
  StartStep.remind: StartEvent.reminded,
  StartStep.folder: StartEvent.foldered,
  StartStep.tag: StartEvent.tagged,
  StartStep.commands: StartEvent.commanded,
};

/// Подсказка показывается не больше стольких заходов.
const tipShowLimit = 3;

class HintsState {
  const HintsState({
    this.off = false,
    this.done = const {},
    this.step = StartStep.stow,
    this.stows = 0,
    this.doneAt,
    this.closed = const {},
    this.shows = const {},
  });

  /// Новичок: первый шаг, ничего не показано.
  static const fresh = HintsState();

  /// Знакомство пройдено, подсказки закрыты: так встречает старых пользователей.
  static const finished = HintsState(step: null, closed: {...Tip.values});

  /// Человек выключил подсказки в настройках.
  final bool off;
  final Set<StartEvent> done;

  /// Открытый шаг; null — знакомство закончено.
  final StartStep? step;

  /// Сколько раз закидывали строкой: шаги ждут новой заметки по нему.
  final int stows;

  /// На каком сохранении сделан (или пропущен) открытый шаг; null — ещё не сделан.
  final int? doneAt;
  final Set<Tip> closed;
  final Map<Tip, int> shows;

  HintsState copyWith({bool? off, Set<StartEvent>? done, StartStep? Function()? step, int? stows, int? Function()? doneAt, Set<Tip>? closed, Map<Tip, int>? shows}) => HintsState(
    off: off ?? this.off,
    done: done ?? this.done,
    step: step == null ? this.step : step(),
    stows: stows ?? this.stows,
    doneAt: doneAt == null ? this.doneAt : doneAt(),
    closed: closed ?? this.closed,
    shows: shows ?? this.shows,
  );
}

/// Шаг, который сейчас стоит над строкой; null — карточки нет.
StartStep? visibleStep(HintsState state) {
  if (state.off || state.step == null || state.doneAt != null) return null;
  return state.step;
}

/// События одного сохранения разом. Сделанный шаг прячет карточку; следующий несделанный
/// открывается на ближайшем сохранении после этого, а после первого шага — сразу.
HintsState hintsAfter(HintsState state, Iterable<StartEvent> events) {
  final stows = state.stows + (events.contains(StartEvent.stowed) ? 1 : 0);
  final done = {...state.done, ...events};
  var next = state.copyWith(stows: stows, done: done);
  final step = next.step;
  if (step == null || step == StartStep.finish) return next;
  final firstDone = step == StartStep.stow && done.contains(StartEvent.stowed);
  if (next.doneAt == null && done.contains(_eventOf[step])) {
    // первая заметка открывает поиск тем же сохранением
    if (firstDone) return _open(next, after: step);
    next = next.copyWith(doneAt: () => stows);
    return next;
  }
  if (next.doneAt != null && stows > next.doneAt!) return _open(next, after: step);
  return next;
}

/// «×» на карточке: шаг уходит, как сделанный; на финальной — знакомство закончено.
HintsState skipStepIn(HintsState state) {
  final step = state.step;
  if (step == null) return state;
  if (step == StartStep.finish) return state.copyWith(step: () => null, doneAt: () => null);
  // первый шаг пропустили — поиск откроется с первой заметкой
  return state.copyWith(doneAt: () => state.stows);
}

/// Следующий несделанный шаг после [after]; все сделаны — финал.
HintsState _open(HintsState state, {required StartStep after}) {
  final rest = StartStep.values.skip(after.index + 1).where((step) => step == StartStep.finish || !state.done.contains(_eventOf[step]));
  return state.copyWith(step: () => rest.first, doneAt: () => null);
}

/// Подсказку можно показать: не выключены, не закрыта, показов меньше трёх.
/// «Зажми заметку» ждёт конца знакомства: на главной не бывает двух советов разом.
bool tipVisible(HintsState state, Tip tip) {
  if (state.off || state.closed.contains(tip) || (state.shows[tip] ?? 0) >= tipShowLimit) return false;
  if (tip == Tip.longPress && state.step != null) return false;
  return true;
}

HintsState tipShownIn(HintsState state, Tip tip) => state.copyWith(shows: {...state.shows, tip: (state.shows[tip] ?? 0) + 1});

HintsState closeTipIn(HintsState state, Tip tip) => state.copyWith(closed: {...state.closed, tip});
