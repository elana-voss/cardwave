"""Refuses a release build that would replace what users already have (.github/workflows/installer.yml).

Usage: python tools/release_guard.py <tag> <owner/repo>

Exits 1, saying why, unless the tag is `v` and the workspace's version (`Cargo.toml`) and the tag's release on
the repo is absent or a draft: `gh release upload --clobber` would otherwise overwrite a published release's
installers and `latest.json`, the feed every installed app updates from. The workflow runs it before the builds
and again right before the upload, since a draft can be published while the builds run (two hours).
The state comes from `gh release view <tag> --json isDraft`, which finds drafts too; "release not found" is the
only failure read as absent, any other (no network, a refused token) stops the run.
"""

import json
import subprocess
import sys

from release_feed import version


def refusal(tag: str, workspace: str, state: str) -> str | None:
    """Why the run must stop, or None. `state` is "absent", "draft" or "published"."""
    if tag != f"v{workspace}":
        return f"the tag {tag!r} is not v{workspace}, the workspace's version (Cargo.toml)"
    if state not in ("absent", "draft"):
        return f"the release {tag} is {state}: its installers and latest.json are what users have"
    return None


def state_of(code: int, out: str, err: str) -> str:
    """The release's state from `gh release view --json isDraft`'s exit code, stdout and stderr."""
    if code:
        if "release not found" in err:
            return "absent"
        sys.exit(f"gh release view failed: {err.strip()}")
    try:
        draft = json.loads(out)["isDraft"]
    except (ValueError, KeyError, TypeError):
        sys.exit(f"gh release view gave no isDraft: {out.strip()!r}")
    return "draft" if draft else "published"


def main() -> None:
    tag, repo = sys.argv[1:3]
    done = subprocess.run(["gh", "release", "view", tag, "--repo", repo, "--json", "isDraft"],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    state = state_of(done.returncode, done.stdout, done.stderr)
    why = refusal(tag, version(), state)
    if why:
        sys.exit(f"Refused: {why}.")
    print(f"{tag}: release {state}, version matches")


if __name__ == "__main__":
    main()
