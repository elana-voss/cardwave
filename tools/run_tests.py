"""Runs every tools/*_test.py, each as its own program: python tools/run_tests.py.

Prints a line per test file that failed with the end of its output, then the count; exits 1 on any failure.
A new tools/<name>_test.py needs no other entry: check.sh's one line `tools-tests` picks it up.
"""

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main() -> int:
    files = sorted(HERE.glob("*_test.py"))
    failed = []
    for file in files:
        done = subprocess.run([sys.executable, str(file)], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if done.returncode:
            failed.append(file.name)
            print(f"== {file.name} failed")
            print("\n".join((done.stdout + done.stderr).strip().splitlines()[-20:]))
    print(f"{len(files) - len(failed)} of {len(files)} tool test files passed" + (f"; failed: {' '.join(failed)}" if failed else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
