"""Раздать собранную веб-версию на своём компьютере с теми же заголовками, что на сервере.

Запуск: python3 tool/web/serve.py <папка сборки> <порт>

Адрес менять нельзя: заметки «в этом браузере» привязаны к нему, и профиль
браузера для проверок открывается только с того же порта.
"""
import functools
import http.server
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.js': 'text/javascript', '.mjs': 'text/javascript'}

    def end_headers(self):
        # без этих двух заголовков база в браузере работает в медленном и ненадёжном режиме
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        # боковая панель расширения встраивает сайт фреймом изолированной страницы (STOWA-9)
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[2])), functools.partial(Handler, directory=sys.argv[1])).serve_forever()
