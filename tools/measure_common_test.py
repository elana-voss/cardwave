"""Tests of tools/measure_common.py, the measuring tools' shared parts: python tools/measure_common_test.py.
No test reaches a provider or starts the app."""

import struct
import sys
import tempfile
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_common as common


def kinds_of(png: bytes) -> list:
    kinds, at = [], 8
    while at < len(png):
        size = struct.unpack(">I", png[at:at + 4])[0]
        kinds.append(png[at + 4:at + 8].decode())
        at += 12 + size
    return kinds


def test_a_card_file_holds_its_card_after_the_picture_as_e2e_card_ts_writes_it():
    data = {"name": "A", "description": "d", "first_mes": "hi", "tags": []}
    assert kinds_of(common.v2_card(data)) == ["IHDR", "IDAT", "tEXt", "IEND"]
    assert kinds_of(common.ccv4_card('spec = "ccv4:1.0.0"\n')) == ["IHDR", "IDAT", "toMl", "IEND"]


class Ended:
    returncode = 3

    def poll(self):
        return 3


def test_waiting_for_the_app_stops_once_its_server_ended():
    try:
        common.App.local(9).wait(Ended(), "server.log")
    except SystemExit as stop:
        assert "ended with 3" in str(stop)
    else:
        raise AssertionError("waited on a server that had ended")


def test_the_proxy_never_holds_the_tool_open_at_its_end():
    assert common.QuietServer.daemon_threads


def test_a_lost_connection_is_answered_as_a_json_error_after_the_tries():
    def opener(request, timeout):
        raise urllib.error.URLError("gone")

    reply, failure, retries, _ = common.fetch("request", opener, lambda seconds: None)
    assert (reply, failure[0], retries) == (None, 502, 4) and b'"message"' in failure[1]


def test_a_stream_line_gives_its_usage_with_the_reasoning():
    piece = common.piece_of(b'data: {"usage": {"prompt_tokens": 7, "completion_tokens": 5, '
                            b'"completion_tokens_details": {"reasoning_tokens": 2}}}\n')
    assert common.usage_of(piece) == (7, 5, 2)
    assert common.piece_of(b"data: [DONE]\n") is None


def test_a_kept_key_is_made_once_and_read_again():
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "db.key"
        first = common.kept_key(path)
        assert len(first) == 64 and common.kept_key(path) == first


if __name__ == "__main__":
    for name, test in sorted(globals().items()):
        if name.startswith("test_"):
            test()
    print("measuring tools' shared parts: tests passed")
