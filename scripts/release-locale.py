#!/usr/bin/env python3
"""Usage: release-locale.py <port> <release URL> <override directory> [missing file...]

Serves the files of the override directory, answers 404 for the missing ones and
redirects every other request to the release.
"""
import http.server
import sys
from pathlib import Path

PORT, RELEASE, REMPLACEMENTS = int(sys.argv[1]), sys.argv[2].rstrip("/"), Path(sys.argv[3])
ABSENTS = set(sys.argv[4:])


class Release(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        nom = self.path.rsplit("/", 1)[-1]
        fichier = REMPLACEMENTS / nom
        if nom in ABSENTS:
            self.send_error(404)
        elif fichier.is_file():
            contenu = fichier.read_bytes()
            self.send_response(200)
            self.send_header("Content-Length", str(len(contenu)))
            self.end_headers()
            self.wfile.write(contenu)
        else:
            self.send_response(302)
            self.send_header("Location", f"{RELEASE}/{nom}")
            self.end_headers()

    def log_message(self, *_):
        pass


http.server.HTTPServer(("127.0.0.1", PORT), Release).serve_forever()
