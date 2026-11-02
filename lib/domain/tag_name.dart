/// Имя тега: нижний регистр, без решёток, края обрезаны, пробелы внутри
/// заменены подчёркиванием. «#Машина » и «МАШИНА» — один тег.
String normalizeTagName(String raw) {
  return raw.trim().replaceFirst(RegExp(r'^#+'), '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
