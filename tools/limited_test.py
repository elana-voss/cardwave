"""Tests of tools/limited.sh: python tools/limited_test.py.

A copy of Windows' ping.exe in a scratch target folder stands in for a hung test program: past the limit `limited`
returns 124 within seconds and no program from that folder runs on; `timed_out` names the limit and the long tests.
"""

import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASH = shutil.which("bash") or r"C:\Program Files\Git\bin\bash.exe"


def sh(script: str) -> subprocess.CompletedProcess:
    return subprocess.run([BASH, "-c", f". '{HERE.as_posix()}/limited.sh'; {script}"], capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=60)


def running_from(folder: Path) -> str:
    probe = f"Get-Process | Where-Object {{ $_.Path -like '{folder}\\*' }} | Measure-Object | % Count"
    return subprocess.run(["powershell.exe", "-NoProfile", "-Command", probe], capture_output=True, text=True).stdout.strip()


def test_a_hung_program_is_stopped_at_the_limit():
    with tempfile.TemporaryDirectory() as scratch:
        target = Path(scratch) / "target"
        target.mkdir()
        hung = target / "hung.exe"
        shutil.copy(r"C:\Windows\System32\PING.EXE", hung)
        # A program from the folder that ran before the check (the owner's app, another run) stays.
        earlier = subprocess.Popen([str(hung), "-n", "60", "127.0.0.1"], stdout=subprocess.DEVNULL)
        time.sleep(1.5)
        begun = time.monotonic()
        done = sh(f"TARGET='{target.as_posix()}' limited 2 '{hung.as_posix()}' -n 60 127.0.0.1; echo \"exit $?\"")
        assert "exit 124" in done.stdout, done.stdout + done.stderr
        assert time.monotonic() - begun < 30
        try:
            assert running_from(target) == "1"
        finally:
            earlier.kill()
            earlier.wait()


def test_a_command_within_the_limit_keeps_its_exit():
    assert "exit 3" in sh("limited 20 sh -c 'exit 3'; echo \"exit $?\"").stdout


def test_timed_out_names_the_limit_and_the_long_tests():
    with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as log:
        log.write("test a ... ok\ntest backup_waits has been running for over 60 seconds\n")
    said = sh(f"timed_out 1800 '{Path(log.name).as_posix()}'").stdout
    Path(log.name).unlink()
    assert said.splitlines() == ["timed out after 1800 s", "test backup_waits has been running for over 60 seconds"]


if __name__ == "__main__":
    for name, test in list(globals().items()):
        if name.startswith("test_"):
            test()
    print("ok")
    sys.exit(0)
