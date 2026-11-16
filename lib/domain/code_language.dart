/// Язык блока кода по слову после ``` : подпись над блоком и имя для подсветки.
library;

/// [label] — как подписать блок («Python», «C++»), [highlight] — язык подсветки
/// (`re_highlight`), null — блок рисуется без подсветки.
typedef CodeLanguage = ({String label, String? highlight});

// подпись и язык подсветки; псевдонимы ведут к одной записи
const _languages = <String, CodeLanguage>{
  'python': (label: 'Python', highlight: 'python'),
  'javascript': (label: 'JavaScript', highlight: 'javascript'),
  'typescript': (label: 'TypeScript', highlight: 'typescript'),
  'dart': (label: 'Dart', highlight: 'dart'),
  'kotlin': (label: 'Kotlin', highlight: 'kotlin'),
  'java': (label: 'Java', highlight: 'java'),
  'swift': (label: 'Swift', highlight: 'swift'),
  'c': (label: 'C', highlight: 'c'),
  'cpp': (label: 'C++', highlight: 'cpp'),
  'csharp': (label: 'C#', highlight: 'csharp'),
  'go': (label: 'Go', highlight: 'go'),
  'rust': (label: 'Rust', highlight: 'rust'),
  'php': (label: 'PHP', highlight: 'php'),
  'ruby': (label: 'Ruby', highlight: 'ruby'),
  'lua': (label: 'Lua', highlight: 'lua'),
  'r': (label: 'R', highlight: 'r'),
  'matlab': (label: 'MATLAB', highlight: 'matlab'),
  'sql': (label: 'SQL', highlight: 'sql'),
  'plsql': (label: 'PL/SQL', highlight: 'sql'),
  'bash': (label: 'Bash', highlight: 'bash'),
  'shell': (label: 'Shell', highlight: 'bash'),
  'powershell': (label: 'PowerShell', highlight: 'powershell'),
  'html': (label: 'HTML', highlight: 'xml'),
  'xml': (label: 'XML', highlight: 'xml'),
  'css': (label: 'CSS', highlight: 'css'),
  'scss': (label: 'SCSS', highlight: 'scss'),
  'json': (label: 'JSON', highlight: 'json'),
  'yaml': (label: 'YAML', highlight: 'yaml'),
  'ini': (label: 'INI', highlight: 'ini'),
  'properties': (label: 'Properties', highlight: 'ini'),
  'markdown': (label: 'Markdown', highlight: 'markdown'),
  'latex': (label: 'LaTeX', highlight: 'latex'),
  'dockerfile': (label: 'Dockerfile', highlight: 'dockerfile'),
  'diff': (label: 'Diff', highlight: 'diff'),
  'csv': (label: 'CSV', highlight: null),
  'text': (label: 'Текст', highlight: null),
  // запросы плагина Obsidian: Dataview похож на SQL, DataviewJS — это JavaScript
  'dataview': (label: 'Dataview', highlight: 'sql'),
  'dataviewjs': (label: 'DataviewJS', highlight: 'javascript'),
};

const _aliases = <String, String>{
  'py': 'python',
  'js': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'kt': 'kotlin',
  'h': 'c',
  'c++': 'cpp',
  'hpp': 'cpp',
  'cc': 'cpp',
  'cs': 'csharp',
  'c#': 'csharp',
  'golang': 'go',
  'rs': 'rust',
  'rb': 'ruby',
  'sh': 'bash',
  'zsh': 'bash',
  'console': 'bash',
  'ps1': 'powershell',
  'pwsh': 'powershell',
  'htm': 'html',
  'svg': 'xml',
  'yml': 'yaml',
  'toml': 'ini',
  'md': 'markdown',
  'tex': 'latex',
  'docker': 'dockerfile',
  'patch': 'diff',
  'txt': 'text',
  'plaintext': 'text',
  'pgsql': 'plsql',
  'postgresql': 'plsql',
  'mysql': 'sql',
};

/// Язык по слову после кавычек: «python», «Py», «c#», «Python {.numberLines}». Незнакомый
/// подписывается как написан и рисуется без подсветки.
CodeLanguage codeLanguage(String info) {
  final word = info.trim().split(RegExp(r'[\s{]')).first;
  final key = word.toLowerCase();
  return _languages[_aliases[key] ?? key] ?? (label: word, highlight: null);
}
