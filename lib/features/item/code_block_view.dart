import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/latex.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/matlab.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/r.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

import '../../core/icons/icon_registry.dart';
import '../../core/theme/folder_palette.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../domain/code_language.dart';
import '../../l10n/app_localizations.dart';

// длинный блок свёрнут до стольких строк; свёртка — только когда прячется заметная часть
const _foldedLines = 14;
const _foldFrom = 20;

/// Блок кода в заметке: подпись языка, подсветка в цветах палитры приложения, прокрутка
/// вбок для длинных строк, «Скопировать», свёртка длинных блоков.
class CodeBlockView extends StatefulWidget {
  const CodeBlockView({super.key, required this.code, this.language, this.onTap});

  final String code;

  /// Слово после ``` как написано; null — блок без подписи и без подсветки.
  final String? language;

  /// Касание по коду — как по тексту заметки: открыть правку.
  final VoidCallback? onTap;

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  bool _open = false;
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final language = widget.language == null ? null : codeLanguage(widget.language!);
    final lines = widget.code.split('\n');
    final foldable = lines.length >= _foldFrom;
    final shown = foldable && !_open ? lines.take(_foldedLines).join('\n') : widget.code;
    final style = TextStyle(fontFamily: 'monospace', fontFamilyFallback: const ['Roboto Mono', 'Menlo', 'Courier'], fontSize: 13.5, height: 1.5, color: Tokens.onSurface);
    final label = Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2, color: Tokens.onSurfaceVariant);
    final link = label.copyWith(color: FolderPalette.ink(Tokens.accent));

    final copy = IconButton(
      tooltip: _copied ? l.codeCopied : l.codeCopy,
      onPressed: _copy,
      visualDensity: VisualDensity.compact,
      icon: AnimatedSwitcher(
        duration: Motion.short,
        child: Icon(
          symbolIcon(_copied ? 'check' : 'content_copy'),
          key: ValueKey(_copied),
          size: 18,
          color: _copied ? FolderPalette.ink(Tokens.accent) : Tokens.onSurfaceVariant,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(color: Tokens.containerLowest, borderRadius: BorderRadius.circular(Radii.tile)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // шапка: язык слева, копирование справа; без языка шапки нет, кнопка — в углу кода
          if (language != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(child: Text(language.label, style: label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  copy,
                ],
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Stack(
              children: [
                SingleChildScrollView(
                  key: const ValueKey('code-scroll'),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(16, language == null ? 14 : 0, language == null ? 52 : 16, foldable ? 4 : 14),
                  child: AnimatedSize(
                    duration: Motion.medium,
                    curve: Motion.emphasized,
                    alignment: Alignment.topLeft,
                    child: RichText(
                      key: const ValueKey('code-text'),
                      softWrap: false,
                      text: _highlighted(shown, language?.highlight, style),
                    ),
                  ),
                ),
                // свёрнутый низ растворяется в подложке: видно, что код продолжается
                if (foldable && !_open)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Tokens.containerLowest.withValues(alpha: 0), Tokens.containerLowest],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (language == null) Positioned(top: 4, right: 4, child: copy),
              ],
            ),
          ),
          if (foldable)
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Icon(symbolIcon(_open ? 'expand_less' : 'expand_more'), size: 18, color: link.color),
                    const SizedBox(width: 6),
                    Text(_open ? l.codeCollapse : l.codeShowAll(lines.length), style: link),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// подсветка — одна на приложение, языки регистрируются при первом блоке
Highlight? _highlight;

Highlight get _highlighter => _highlight ??= Highlight()
  ..registerLanguages({
    'bash': langBash,
    'c': langC,
    'cpp': langCpp,
    'csharp': langCsharp,
    'css': langCss,
    'dart': langDart,
    'diff': langDiff,
    'dockerfile': langDockerfile,
    'go': langGo,
    'ini': langIni,
    'java': langJava,
    'javascript': langJavascript,
    'json': langJson,
    'kotlin': langKotlin,
    'latex': langLatex,
    'lua': langLua,
    'markdown': langMarkdown,
    'matlab': langMatlab,
    'php': langPhp,
    'powershell': langPowershell,
    'python': langPython,
    'r': langR,
    'ruby': langRuby,
    'rust': langRust,
    'scss': langScss,
    'sql': langSql,
    'swift': langSwift,
    'typescript': langTypescript,
    'xml': langXml,
    'yaml': langYaml,
  });

// разобранное помнится: страница перерисовывается на каждую правку рядом
final _cache = <(String, String, bool), TextSpan>{};

/// Код в цветах: оттенки палитры папок (пастель в тёмной теме, тот же оттенок темнее в
/// светлой — через [FolderPalette.ink]). Язык не знаком или разбор упал — код одним цветом.
TextSpan _highlighted(String code, String? language, TextStyle base) {
  if (language == null) return TextSpan(text: code, style: base);
  final key = (code, language, Tokens.palette.isDark);
  if (_cache[key] case final cached?) return cached;
  TextSpan span;
  try {
    final renderer = TextSpanRenderer(base, _theme());
    _highlighter.highlight(code: code, language: language, ignoreIllegals: true).render(renderer);
    span = renderer.span ?? TextSpan(text: code, style: base);
  } on Object {
    span = TextSpan(text: code, style: base);
  }
  if (_cache.length > 64) _cache.clear();
  return _cache[key] = span;
}

Map<String, TextStyle> _theme() {
  TextStyle ink(String key) => TextStyle(color: FolderPalette.ink(FolderPalette.colors[key]!));
  final keyword = ink('violet');
  final string = ink('lime');
  final number = ink('amber');
  final title = ink('sky');
  final type = ink('teal');
  final attribute = ink('rose');
  final comment = TextStyle(color: Tokens.muted, fontStyle: FontStyle.italic);
  return {
    'keyword': keyword,
    'selector-tag': keyword,
    'literal': keyword,
    'doctag': keyword,
    'meta-keyword': keyword,
    'operator': TextStyle(color: Tokens.onSurfaceVariant),
    'string': string,
    'regexp': string,
    'meta-string': string,
    'template-tag': string,
    'addition': string,
    'number': number,
    'symbol': number,
    'bullet': number,
    'variable.language_': number,
    'title': title,
    'title.function_': title,
    'section': title.copyWith(fontWeight: FontWeight.w700),
    'name': title,
    'selector-id': title,
    'selector-class': title,
    'type': type,
    'built_in': type,
    'title.class_': type,
    'title.class_.inherited__': type,
    'attr': attribute,
    'attribute': attribute,
    'variable': attribute,
    'template-variable': attribute,
    'selector-attr': attribute,
    'selector-pseudo': attribute,
    'subst': TextStyle(color: Tokens.onSurface),
    'comment': comment,
    'quote': comment,
    'meta': TextStyle(color: Tokens.muted),
    'deletion': ink('coral'),
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.w700),
  };
}
