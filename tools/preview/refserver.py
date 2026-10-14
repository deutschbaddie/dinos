"""Static server for tools/preview plus POST /save?name=x.png (a data: URL body) -> art/refs/x.png.
Used by refs.html to export reference renders of the real models."""
import base64
import http.server
import os
import re
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(ROOT, "..", "..", "art", "refs"))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        if u.path != "/save":
            self.send_error(404)
            return
        name = urllib.parse.parse_qs(u.query).get("name", ["render.png"])[0]
        name = re.sub(r"[^A-Za-z0-9_.-]", "_", name)
        if not name.endswith(".png"):
            name += ".png"
        body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode()
        data = base64.b64decode(body.split(",", 1)[1])
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8781
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
