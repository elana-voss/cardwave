"""What tools/greeting_measure.py must not lose, on made-up data: a call's tokens when the server has gone, a unit
that cannot be read. Run: python tools/greeting_measure_test.py (tools/check.sh's `greeting-tool`)."""

import io
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import greeting_measure as tool


class GoneServer(io.BytesIO):
    """The server stopped reading: every write after the first raises, as a closed socket does."""

    def __init__(self):
        super().__init__()
        self.writes = 0

    def write(self, data):
        self.writes += 1
        if self.writes > 1:
            raise BrokenPipeError
        return super().write(data)


def test_a_call_is_counted_when_the_server_stops_reading():
    with tempfile.TemporaryDirectory() as folder:
        usage = tool.Usage(Path(folder) / "usage.json", 0, 1000)
        handler = object.__new__(tool.proxy_class(usage, "made-up"))
        handler.wfile = GoneServer()
        handler.send_response = handler.send_header = lambda *_: None
        handler.end_headers = lambda: None
        said = {"usage": {"prompt_tokens": 7, "completion_tokens": 5}}
        reply = io.BytesIO(b"data: " + json.dumps(said).encode() + b"\n\ndata: [DONE]\n\n")
        reply.status, reply.headers = 200, {}
        try:
            handler.pass_on(reply, "writer_card")
        except BrokenPipeError:
            pass  # The proxy's server swallows this; here only the count matters.
        assert usage.roles["writer_card"] == {"calls": 1, "in": 7, "out": 5}


def test_a_unit_that_cannot_be_read_is_a_failure_of_that_unit():
    with tempfile.TemporaryDirectory() as folder:
        unit = Path(folder) / "us-made-up.json"
        unit.write_text("{}", encoding="utf-8")
        name, failure = tool.write_one("http://127.0.0.1:9", Path(folder), unit, Path(folder))
        assert name == "us-made-up" and failure.startswith("failed")


def test_every_takes_every_nth_of_the_sorted_list():
    with tempfile.TemporaryDirectory() as folder:
        units = Path(folder) / "cards" / "units"
        units.mkdir(parents=True)
        for number in [4, 1, 3, 0, 5, 2, 6]:
            (units / f"us-{number}.json").write_text("{}", encoding="utf-8")
        assert [file.stem for file in tool.units_of(Path(folder), 3)] == ["us-0", "us-3", "us-6"]


if __name__ == "__main__":
    for name, test in sorted(globals().items()):
        if name.startswith("test_"):
            test()
    print("greeting tool: tests passed")
