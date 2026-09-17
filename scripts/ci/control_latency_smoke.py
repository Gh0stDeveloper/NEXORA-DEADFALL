#!/usr/bin/env python3
"""Exercise the real HTTPClient probe against a persistent HTTP/1.1 server."""
import http.server
import os
from pathlib import Path
import subprocess
import tempfile
import threading


class Server(http.server.ThreadingHTTPServer):
    connections = 0

    def get_request(self):
        self.connections += 1
        return super().get_request()


class Health(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        body = b'{"ok":true}' if self.path == "/v1/health" else b'{"ok":false}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def main():
    repo = Path(__file__).resolve().parents[2]
    with Server(("127.0.0.1", 0), Health) as server, tempfile.TemporaryDirectory() as profile:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        result = subprocess.run(
            [os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(repo),
             "--script", "scripts/ci/control_latency_smoke.gd", "--",
             f"--control-test-port={server.server_port}"],
            env=dict(os.environ, XDG_DATA_HOME=profile), timeout=25,
            stdout=None, stderr=subprocess.STDOUT, text=True,
        )
        server.shutdown()
        assert result.returncode == 0
        # Three healthy probes share one socket; changing the base for /bad opens one more.
        assert server.connections == 2, f"Expected connection reuse, got {server.connections} sockets"
        print("Persistent HTTP/1.1 connection reuse passed")


if __name__ == "__main__":
    main()
