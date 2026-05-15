# Name database generator

One-shot offline tooling for `packages/cardwave_names/assets/name_database.json`.
Not invoked by the app. Run it from the host machine when you want to
(re)generate the NPC name pool.

The build runs in two phases — Phase 1 is deterministic and costs nothing;
Phase 2 calls Anthropic's API to classify the subjective tags. Phase 1's
output is itself reviewable, so the corpus-ingestion step can be debugged
before any tokens get spent.

Claude never **invents** names. The corpora supply the names; Claude only
assigns tags (age, role, intelligence, allure, themes, genre) to the
sentinel fields each loader couldn't fill from source metadata.

## Prerequisites

- A working `dart` / `flutter` toolchain (uses the app's pubspec).
- `git` on PATH (the fetch step clones the corpus repos).
- An Anthropic API key (Phase 2 only).

## Usage

```
# From the app/ folder:
dart run tools/generate_names/dataset_fetch.dart
dart run tools/generate_names/build_candidate.dart
dart run --define=ANTHROPIC_API_KEY=sk-ant-... tools/generate_names/classify.dart
```

`dataset_fetch.dart` is idempotent: re-running is a no-op once
`../memory-bank/name_datasets/.fetched` exists. To force a refresh,
delete that marker file and re-run.

`build_candidate.dart` (Phase 1, no API cost) runs the 11 per-corpus
loaders, dedupes case-insensitive across sources, fills source-deducible
tags (gender / language_ethnicity / race per corpus), marks the rest as
sentinels, and writes
`packages/cardwave_names/assets/name_database.candidate.json`.

`classify.dart` (Phase 2) reads the candidate file, batches ~25 entries
to Claude per request to fill the sentinel fields, and writes the final
`packages/cardwave_names/assets/name_database.json`. Per-batch progress
in `tools/generate_names/.progress` lets a failed run resume without
re-billing.

> `build_candidate.dart`, `classify.dart`, and `inspect.dart` are pending
> implementation. The README documents the intended flow so consumers
> know what to run once the scripts ship. `dataset_fetch.dart` is in
> place today.

### Useful flags

- `--limit=N` (`classify.dart`): cap at the first N batches. Use this
  for a small smoke run (e.g. `--limit=2`) before paying for the full
  pass.

## Human review

Before committing the generated `name_database.json`, sample 50–100
entries and eyeball for absurd tag combinations (e.g. "Mary" tagged
allure=5), accidental cultural insensitivity, and false cognates. The
companion `inspect.dart` script prints random samples grouped by
culture / race so the review isn't done by hand-grepping the JSON. The
README in `memory-bank/name_datasets/` lists the corpora used.

## Provider

Uses Anthropic Claude (`claude-sonnet-4-6` by default — classification
is much easier than generation and sonnet handles tag assignment at
~5× the cost saving over opus). To switch models, edit the constant at
the top of `classify.dart`. Override to opus if a sample shows quality
drift.
