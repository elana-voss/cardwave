"""Tests of tools/sentences.py: python tools/sentences_test.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sentences import sentences


def test_a_field_set_to_a_sentence_is_found():
    text = 'S {\n    label: "Searching the web: {}",\n}\n'
    assert sentences("crates/cw-x/src/a.rs", text) == ["crates/cw-x/src/a.rs: label: Searching the web: {}"]


def test_push_let_arm_and_else_are_found():
    text = "\n".join([
        'v.push(format!("Some words {}", x));',
        'let note = "Before step {}";',
        'x => "Gone away",',
        '} else { "Not there" }',
        "",
    ])
    assert sentences("server/src/a.rs", text) == [
        "server/src/a.rs: push: Some words {}",
        "server/src/a.rs: let note: Before step {}",
        "server/src/a.rs: =>: Gone away",
        "server/src/a.rs: else: Not there",
    ]


def test_codes_one_word_and_test_code_are_left():
    text = "\n".join([
        '    code: "not_found",',
        '    let title = "Untitled";',
        "#[cfg(test)]",
        "mod tests {",
        '    label: "Searching the web",',
        "}",
        "",
    ])
    assert sentences("crates/cw-x/src/a.rs", text) == []


def test_allowed_fields_and_files_are_left():
    assert sentences("crates/cw-x/src/a.rs", '    what: "A prompt line",\n') == []
    assert sentences("crates/cw-prompt/src/builder.rs", 'let line = "You are here";\n') == []
    assert sentences("crates/cw-coding/src/run.rs", 'let brief = "The goal is";\n') == []
    assert sentences("crates/cw-coding/src/run.rs", 'let brief = "Other words";\n') != []


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
    print("ok")
