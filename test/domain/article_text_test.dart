import 'package:flutter_test/flutter_test.dart';
import 'package:stowa/domain/article_text.dart';

final _page = Uri.parse('https://blog.example.com/posts/kofe');

// абзац с запятыми и длиной, как в настоящей статье: слов ~40
String _paragraph(int index) =>
    '<p>Абзац номер $index рассказывает, как варить кофе дома, если турки нет, а кофемашина стоит дорого, '
    'и почему вода важнее зёрен, когда речь о вкусе, крепости и запахе по утрам, '
    'особенно зимой, когда за окном темно и хочется чего-то тёплого и простого.</p>';

String _body(int paragraphs) => [for (var index = 1; index <= paragraphs; index++) _paragraph(index)].join('\n');

void main() {
  test('статья внутри <article>: меню, шапка, подвал и скрипты не попадают в текст', () {
    final html = '''<html><head>
      <title>Кофе без турки — Блог</title>
      <meta property="og:title" content="Кофе без турки">
      <meta property="og:site_name" content="Блог про кофе">
      <meta name="author" content="Анна Петрова">
      <meta property="article:published_time" content="2026-10-01T09:00:00Z">
      <script>var tracking = "не текст";</script>
    </head><body>
      <header><a href="/">Главная</a> <a href="/about">О нас</a></header>
      <nav><ul><li><a href="/a">Раздел А</a></li><li><a href="/b">Раздел Б</a></li></ul></nav>
      <article><h1>Кофе без турки</h1>${_body(6)}</article>
      <footer>© 2026 Все права защищены</footer>
    </body></html>''';
    final article = extractArticle(html, _page)!;
    expect(article.title, 'Кофе без турки');
    expect(article.site, 'Блог про кофе');
    expect(article.byline, 'Анна Петрова');
    expect(article.published, DateTime.utc(2026, 10, 1, 9));
    // заголовок не повторяется первым блоком
    expect(article.blocks.first.kind, ArticleBlockKind.paragraph);
    expect(article.blocks.where((block) => block.kind == ArticleBlockKind.paragraph), hasLength(6));
    expect(article.plainText, isNot(contains('Главная')));
    expect(article.plainText, isNot(contains('Все права')));
    expect(article.plainText, isNot(contains('tracking')));
    expect(article.words, greaterThan(200));
    expect(article.minutes, (article.words / 200).ceil());
  });

  test('без <article>: корень текста выбирается по очкам абзацев, боковая колонка мимо', () {
    final html = '''<html><body>
      <div class="layout">
        <div class="sidebar"><p>Подпишись на рассылку, чтобы ничего не пропустить.</p><p><a href="/1">Похожее 1</a></p></div>
        <div class="post-content">${_body(6)}</div>
        <div class="comments"><p>Комментарий: отличная статья, спасибо, очень полезно, сохранил себе.</p></div>
      </div>
    </body></html>''';
    final article = extractArticle(html, _page)!;
    expect(article.blocks, hasLength(6));
    expect(article.plainText, isNot(contains('рассылку')));
    expect(article.plainText, isNot(contains('Комментарий')));
  });

  test('подзаголовок, цитата, список, код и картинка с адресом от страницы и подписью', () {
    final html = '''<html><body><article>
      ${_body(6)}
      <h2>Что понадобится</h2>
      <ul><li>Молотый кофе</li><li>Горячая вода</li></ul>
      <ol><li>Насыпать</li><li>Залить</li></ol>
      <blockquote><p>Кофе — это повод проснуться.</p></blockquote>
      <pre><code>вода = 200 мл</code></pre>
      <figure><img src="/img/cup.jpg" alt="Чашка"><figcaption>Чашка утром</figcaption></figure>
      <img data-src="https://cdn.example.com/lazy.webp" src="data:image/gif;base64,R0lGOD">
    </article></body></html>''';
    final article = extractArticle(html, _page)!;
    final kinds = [for (final block in article.blocks) block.kind];
    expect(kinds, containsAllInOrder([ArticleBlockKind.heading, ArticleBlockKind.item, ArticleBlockKind.item, ArticleBlockKind.quote, ArticleBlockKind.code, ArticleBlockKind.image]));
    final heading = article.blocks.firstWhere((block) => block.kind == ArticleBlockKind.heading);
    expect(heading.text, 'Что понадобится');
    expect(heading.level, 2);
    final items = article.blocks.where((block) => block.kind == ArticleBlockKind.item).toList();
    expect([for (final item in items) item.text], ['Молотый кофе', 'Горячая вода', 'Насыпать', 'Залить']);
    expect(items.first.ordered, isFalse);
    expect(items.last.ordered, isTrue);
    expect(article.blocks.firstWhere((block) => block.kind == ArticleBlockKind.quote).text, 'Кофе — это повод проснуться.');
    expect(article.blocks.firstWhere((block) => block.kind == ArticleBlockKind.code).text, 'вода = 200 мл');
    final images = article.blocks.where((block) => block.kind == ArticleBlockKind.image).toList();
    expect(images.first.src, 'https://blog.example.com/img/cup.jpg');
    expect(images.first.text, 'Чашка утром');
    // ленивая картинка: настоящий адрес в data-src, заглушка в src
    expect(images.last.src, 'https://cdn.example.com/lazy.webp');
  });

  test('товар с тремя строками — не статья', () {
    const html = '<html><body><div class="product"><h1>Кофемолка</h1><p>Цена 900 лей</p><p>В наличии</p><button>Купить</button></div></body></html>';
    expect(extractArticle(html, _page), isNull);
  });

  test('меню из абзацев со ссылками не становится текстом статьи', () {
    final menu = [for (var index = 0; index < 12; index++) '<p><a href="/s$index">Раздел сайта номер $index, где собраны все статьи о кофе и чае</a></p>'].join();
    final html = '<html><body><div class="links">$menu</div><div class="text">${_body(6)}</div></body></html>';
    final article = extractArticle(html, _page)!;
    expect(article.plainText, isNot(contains('Раздел сайта')));
    expect(article.blocks, hasLength(6));
  });

  test('служебный <link> посреди абзаца (Википедия) не рвёт абзац', () {
    final html = '<html><body><article>${_body(6)}<p>Трактат <i>De Saluberrima</i><link rel="mw:PageProp/Category" href="./x"/> (Рим, 1671) о кофе.</p></article></body></html>';
    final article = extractArticle(html, _page)!;
    expect(article.blocks.last.text, 'Трактат De Saluberrima (Рим, 1671) о кофе.');
  });

  test('хвост сайта в заголовке убирается: «Coffee - Wikipedia» → «Coffee»', () {
    final html = '<html><head><title>Coffee - Wikipedia</title></head><body><article>${_body(6)}</article></body></html>';
    expect(extractArticle(html, Uri.parse('https://en.wikipedia.org/wiki/Coffee'))!.title, 'Coffee');
    final named = '<html><head><meta property="og:title" content="Кофе без турки | Блог про кофе"><meta property="og:site_name" content="Блог про кофе"></head><body><article>${_body(6)}</article></body></html>';
    expect(extractArticle(named, _page)!.title, 'Кофе без турки');
    // тире внутри самого заголовка не трогается
    final dash = '<html><head><meta property="og:title" content="Кофе — это повод проснуться"></head><body><article>${_body(6)}</article></body></html>';
    expect(extractArticle(dash, _page)!.title, 'Кофе — это повод проснуться');
  });

  test('перенос <br> внутри абзаца остаётся переносом строки', () {
    final html = '<html><body><article>${_body(6)}<p>Первая строка<br>вторая строка</p></article></body></html>';
    final article = extractArticle(html, _page)!;
    expect(article.blocks.last.text, 'Первая строка\nвторая строка');
  });
}
