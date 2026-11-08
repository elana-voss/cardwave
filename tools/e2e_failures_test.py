"""Tests of tools/e2e_failures.py: python tools/e2e_failures_test.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from e2e_failures import outcome


def test_a_run_that_ended_before_its_tests_says_so():
    said = outcome("Error: npm --prefix web run build failed:\nsrc/x.ts(3,1): error TS2304\n")
    assert said.startswith("the run ended before its tests"), said
    assert "npm --prefix web run build failed" in said


def test_a_finished_run_gives_its_counts():
    assert outcome("  2 failed\n  1 did not run\n  30 passed (41.7s)\n") == "30 passed, 2 failed, 1 did not run"


if __name__ == "__main__":
    for name, test in sorted(globals().items()):
        if name.startswith("test_"):
            test()
