"""Tests of tools/release_guard.py: python tools/release_guard_test.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from release_guard import refusal, state_of


def test_only_the_workspace_versions_tag_with_no_release_or_a_draft_passes():
    assert refusal("v0.3.1", "0.3.1", "absent") is None
    assert refusal("v0.3.1", "0.3.1", "draft") is None
    for tag, state in [("v0.3.1", "published"), ("v0.3.0", "absent"), ("0.3.1", "draft"), ("v0.3.1 ", "absent"), ("v0.3.10", "draft")]:
        assert refusal(tag, "0.3.1", state), (tag, state)


def test_the_release_state_is_read_from_gh_and_any_other_failure_of_gh_is_no_state():
    assert state_of(0, '{"isDraft":true}\n', "") == "draft"
    assert state_of(0, '{"isDraft":false}\n', "") == "published"
    assert state_of(1, "", "release not found\n") == "absent"
    for code, out, err in [(1, "", "HTTP 401: Bad credentials"), (0, "", ""), (0, "{}", "")]:
        try:
            state_of(code, out, err)
        except SystemExit as stop:
            assert stop.code, (code, out, err)
        else:
            raise AssertionError((code, out, err))


if __name__ == "__main__":
    test_only_the_workspace_versions_tag_with_no_release_or_a_draft_passes()
    test_the_release_state_is_read_from_gh_and_any_other_failure_of_gh_is_no_state()
    print("ok")
