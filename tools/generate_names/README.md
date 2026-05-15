# Name database generator

One-shot offline tooling for `packages/cardwave_names/assets/name_database.json`.
Not invoked by the app. Run it from the host machine when you want to
(re)generate the NPC name pool.

## Prerequisites

- A working `dart` / `flutter` toolchain (uses the app's pubspec).
- `git` on PATH (the fetch step clones two corpus repos).
- An Anthropic API key.

## Usage

```
# From the app/ folder:
dart run tools/generate_names/dataset_fetch.dart
dart run --define=ANTHROPIC_API_KEY=sk-ant-... tools/generate_names/generate.dart
```

`dataset_fetch.dart` is idempotent: re-running is a no-op once
`../memory-bank/name_datasets/.fetched` exists. To force a refresh,
delete that marker file and re-run.

`generate.dart` writes the result to
`packages/cardwave_names/assets/name_database.json` and tracks per-batch
progress in `tools/generate_names/.progress` so a failed run can resume
without re-billing for completed batches.

### Useful flags

- `--limit=N` (`generate.dart`): cap at the first N batches. Use this
  for a small smoke run (e.g. `--limit=4`) before paying for the full
  pass.

## Human review

Before committing the generated `name_database.json`, scan the output
for cultural sensitivity issues, accidental slurs, and false cognates.
LLM-generated names from a multi-culture pool will occasionally produce
something that reads fine in one language and very wrong in another.
The README in `memory-bank/name_datasets/` lists the corpora used; the
philipperemy dataset is a useful spot-check.

## Provider

Uses Anthropic Claude (`claude-opus-4-7` by default). To switch to a
different model, edit the constant at the top of `generate.dart`. The
project's primary LLM provider for development work is Anthropic — keep
the script there unless there's a reason to diverge.
