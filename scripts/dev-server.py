#!/usr/bin/env python3
"""开发服务器：带 no-cache 响应头，浏览器永不缓存本地资源。

用法：python3 scripts/dev-server.py [端口=4173] [目录=.]
"""
import functools
import http.server
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 4173
DIRECTORY = sys.argv[2] if len(sys.argv) > 2 else "."


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, format, *args):  # 安静模式：只记录错误
        if self.command not in ("GET", "HEAD"):
            super().log_message(format, *args)


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    handler = functools.partial(NoCacheHandler, directory=DIRECTORY)
    with socketserver.TCPServer(("0.0.0.0", PORT), handler) as httpd:
        print(f"dev server (no-cache) → http://localhost:{PORT}")
        httpd.serve_forever()
