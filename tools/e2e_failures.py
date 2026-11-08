"""The failed browser tests of the last run, one line each, from e2e/test-results.

Each `error-context.md` there names its test's place and its error; this prints
`<spec>:<line> | <first error line> | <locator, expected, received, what it waited for> | <the failing line>` per failed test, so
the failures are read without the page snapshots. A picture that differs says
`toHaveScreenshot`. Run from the root the tests ran in (a worktree's too): `python tools/e2e_failures.py [<the run's output file>]`;
with the run's output it first says the run's counts, or that the run ended before its tests (a failed build
leaves no failures in test-results, which alone would read as none).
"""

import pathlib
import re
import sys

# The run's own folder: a worktree's run writes its results there, not beside this file.
ROOT = pathlib.Path.cwd() / "e2e" / "test-results"


def summary(text: str) -> str:
    place = re.search(r"- Location: (\S+)", text)
    details = text.split("# Error details", 1)[-1].split("```yaml", 1)[0]
    lines = [line.strip() for line in details.splitlines() if line.strip() and line.strip() != "```"]
    error = next((line for line in lines if line.startswith("Error")), "?")
    marks = ("Locator:", "Expected", "Received", "- waiting for")
    what = " | ".join(line[:120] for line in lines if line.startswith(marks))
    source = re.search(r"^> +(\d+) \|(.*)$", text, re.M)
    failing = f" | at {source.group(1)}:{source.group(2).strip()[:150]}" if source else ""
    return f"{place.group(1) if place else '?'} | {error[:70]} | {what}{failing}".rstrip()


def outcome(run: str) -> str:
    """The run's counts from Playwright's last lines, or why it has none."""
    counts = re.findall(r"^\s*(\d+) (passed|failed|flaky|skipped|did not run)\b", run, re.M)
    if counts:
        order = ("passed", "failed", "flaky", "skipped", "did not run")
        return ", ".join(f"{n} {kind}" for kind in order for n, k in counts if k == kind)
    errors = [line.strip() for line in run.splitlines() if "rror" in line][:3]
    return "the run ended before its tests: " + (" | ".join(errors)[:300] or run.strip()[-300:])


def main() -> None:
    if len(sys.argv) > 1:
        print(outcome(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")))
    found = sorted(ROOT.glob("*/error-context.md")) if ROOT.exists() else []
    for path in found:
        print(summary(path.read_text(encoding="utf-8")))
    print(f"{len(found)} failed")


if __name__ == "__main__":
    main()
