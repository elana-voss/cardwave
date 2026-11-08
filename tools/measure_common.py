"""The measuring tools' shared parts (greeting_measure, helper_measure, needs_measure): the proxy that stands between
the app and a provider (its handler, the retries, a stream's usage), a free port, the app driver and the card files.

Each tool keeps what it counts: the proxy's handler here only answers, reads and forwards; a tool's subclass
decides what is measured and writes it down. Traps: the app reads no provider's usage, so a tool asks for it
(`upstream_request` adds `stream_options`); the app is started with a database key of the tool's, never the OS
credential store, which the owner's own Cardwave uses. A card file is the PNG e2e/card.ts writes: the card's
chunk after the picture. Tests: tools/measure_common_test.py.
"""

import base64
import http.server
import json
import os
import secrets
import socket
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zlib
from pathlib import Path


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


class QuietServer(http.server.ThreadingHTTPServer):
    """The proxy's server: a call still waiting on a provider never holds the tool open at its end."""

    daemon_threads = True

    def handle_error(self, request, client_address):
        pass  # The app closing a kept connection is no failure.


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    """What every tool's proxy does alike; a tool's subclass answers POST."""

    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass  # A tool writes what was asked itself; the server's own log tells what went wrong.

    def send(self, status: int, kind: str, data: bytes):
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def refuse(self, status: int, why: str):
        self.send(status, "application/json", json.dumps({"error": {"message": why}}).encode())

    def do_GET(self):
        self.refuse(404, "this proxy answers no GET")

    def body(self) -> dict:
        return json.loads(self.rfile.read(int(self.headers["Content-Length"])) or b"{}")


def upstream_request(base: str, path: str, body: dict, key: str) -> urllib.request.Request:
    """The app's call as the provider gets it: under the provider's address, with the key, a stream asked for its usage."""
    if body.get("stream"):
        body["stream_options"] = {"include_usage": True}
    return urllib.request.Request(base + path.removeprefix("/v1"), data=json.dumps(body).encode(),
                                  headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})


def fetch(request, opener, sleep, timeout: int = 300) -> tuple:
    """(reply, None, retries, the last try's start) or (None, (code, body), ...): waits and asks again on 429, 5xx and a
    lost connection, at most five tries; any other refusal is returned at once, as the provider said it."""
    for attempt in range(5):
        started = time.time()
        try:
            return opener(request, timeout=timeout), None, attempt, started
        except urllib.error.HTTPError as failure:
            if attempt < 4 and (failure.code == 429 or failure.code >= 500):
                sleep(5 * (attempt + 1))
                continue
            return None, (failure.code, failure.read()[:2000]), attempt, started
        except (urllib.error.URLError, TimeoutError, OSError) as failure:
            if attempt < 4:
                sleep(5 * (attempt + 1))
                continue
            return None, (502, json.dumps({"error": {"message": str(failure)}}).encode()), attempt, started
    raise AssertionError("unreachable: the last try returns")


def piece_of(line) -> dict | None:
    """A stream's line (`data: {...}`, bytes or text) or a whole JSON answer as a dict; None for [DONE] and the like."""
    text = line.decode(errors="replace") if isinstance(line, bytes) else line
    try:
        piece = json.loads(text.strip().removeprefix("data:").strip())
    except json.JSONDecodeError:
        return None  # [DONE] and empty lines carry nothing.
    return piece if isinstance(piece, dict) else None


def usage_of(piece: dict) -> tuple | None:
    """(prompt, completion, reasoning) tokens the provider said; None where it said none."""
    said = piece.get("usage")
    if not said:
        return None
    details = said.get("completion_tokens_details") or {}
    return said.get("prompt_tokens", 0), said.get("completion_tokens", 0), details.get("reasoning_tokens", 0) or 0


def png(chunks: list) -> bytes:
    """A one-pixel PNG with `chunks` (kind, body) after its picture."""
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    header = struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)
    middle = b"".join(chunk(kind, body) for kind, body in chunks)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(b"\0\x90")) + middle + chunk(b"IEND", b"")


def v2_card(data: dict) -> bytes:
    """A SillyTavern V2 card file of the card's `data` (name, description, first_mes, tags, ...)."""
    text = base64.b64encode(json.dumps({"spec": "chara_card_v2", "spec_version": "2.0", "data": data}).encode())
    return png([(b"tEXt", b"chara\0" + text)])


def ccv4_card(toml: str) -> bytes:
    """A CCV4 card file of one TOML file."""
    return png([(b"toMl", b"ccv4\0card/0001_card.toml\0" + toml.encode())])


def kept_key(path: Path) -> str:
    """A database key kept in `path`, made there once, so a rerun opens the data folder it left."""
    if not path.exists():
        path.write_text(secrets.token_hex(32), encoding="utf-8")
    return path.read_text(encoding="utf-8").strip()


def start_app(exe, port: int, data: Path, log, key: str | None = None) -> subprocess.Popen:
    """The app's server on `port` and its data folder, writing to `log` (a file or DEVNULL); `key` its database key,
    else a fresh one."""
    env = {**os.environ, "CARDWAVE_DB_KEY": key or secrets.token_hex(32)}
    return subprocess.Popen([str(Path(exe).resolve()), "--port", str(port), "--data-dir", str(data)],
                            env=env, stdout=log, stderr=subprocess.STDOUT)


class Refused(RuntimeError):
    """The app answered a call with a failure: its status and what it said."""

    def __init__(self, status: int, said):
        super().__init__(f"{status}: {str(said)[:200]}")
        self.status, self.said = status, said


class App:
    """The app's HTTP interface: `call` answers (status, JSON or text), `must` the JSON of a call that has to succeed."""

    def __init__(self, address: str, timeout: int = 60):
        self.base, self.timeout = address, timeout

    @classmethod
    def local(cls, port: int, timeout: int = 60) -> "App":
        return cls(f"http://127.0.0.1:{port}", timeout)

    def call(self, method: str, path: str, body=None, raw: bytes | None = None, timeout: int | None = None) -> tuple:
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        headers = {} if raw is not None else {"Content-Type": "application/json"}
        request = urllib.request.Request(self.base + path, data, headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=timeout or self.timeout) as reply:
                text = reply.read()
                return reply.status, (json.loads(text) if text else None)
        except urllib.error.HTTPError as failure:
            said = failure.read().decode(errors="replace")
            try:
                return failure.code, json.loads(said)
            except json.JSONDecodeError:
                return failure.code, said[:500]

    def must(self, method: str, path: str, body=None, raw: bytes | None = None, timeout: int | None = None):
        status, said = self.call(method, path, body, raw, timeout)
        if status >= 400:
            raise Refused(status, said)
        return said

    def wait(self, server: subprocess.Popen, log) -> None:
        """Until the app answers anything, at most a minute; ends the tool if its server ended or never answered."""
        for _ in range(120):
            if server.poll() is not None:
                sys.exit(f"the server ended with {server.returncode}; see {log}")
            try:
                self.call("GET", "/api/provider", timeout=2)
                return
            except (urllib.error.URLError, OSError):
                time.sleep(0.5)
        sys.exit("the server did not answer")
