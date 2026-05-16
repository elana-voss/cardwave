# Name database generator

One-shot offline tooling for the const-baked NPC name database at
`packages/cardwave_names/lib/src/services/name_database_data.dart`.
Not invoked by the app. Run it from the host machine when you want to
(re)generate the NPC name pool.

The build runs in three phases:

1. **Phase 1** (deterministic, free) — `build_candidate.dart` ingests
   the corpora and `slim_candidate.dart` caps the per-pool counts.
2. **Phase 2** (paid) — `classify.dart` calls Grok 4.3 to fill the
   subjective tags.
3. **Phase 3** (deterministic, free) — `emit_dart.dart` converts the
   tagged JSON into a Dart const file the package compiles in.

Phase 1's output is itself reviewable, so the corpus-ingestion step
can be debugged before any tokens get spent.

Grok never **invents** names. The corpora supply the names; Grok only
assigns tags (age, role, intelligence, allure, commonness, themes,
genre) to the sentinel fields each loader couldn't fill from source
metadata.

## Prerequisites

- A working `dart` / `flutter` toolchain (uses the app's pubspec).
- `git` on PATH (the fetch step clones the corpus repos).
- Python 3 on PATH (one corpus, `philipperemy`, ships Python pickles
  that need a one-shot conversion to JSON before the Dart loader can
  read them — see step 2 below).
- A Grok / xAI API key in `secrets/test-secrets.env` as `GROK_API_KEY=xai-...`
  (Phase 2 only). The `scripts-dev/run_classify.{ps1,sh}` wrappers
  source that file and pass the key to classify.dart via `--dart-define`.

## Usage

```
# From the repo root:
dart run tools/generate_names/dataset_fetch.dart
python app/tools/generate_names/philipperemy_to_json.py
cd app
dart run tools/generate_names/build_candidate.dart
dart run tools/generate_names/slim_candidate.dart
# Phase 2 (paid, ~5-10 min, ~$0.05-0.10 at ~440K tokens total):
../scripts-dev/run_classify.ps1     # or run_classify.sh
dart run tools/generate_names/emit_dart.dart
```

`dataset_fetch.dart` is idempotent: re-running is a no-op once
`../memory-bank/name_datasets/.fetched` exists. To force a refresh,
delete that marker file and re-run.

`philipperemy_to_json.py` reads the two pickles
(`philipperemy/names_dataset/v3/{first,last}_names.pkl.gz`) and pivots
them into per-country JSON files at
`philipperemy/converted/<COUNTRY>_{first,last}.json`. Top 100 names per
country by rank (caps immigrant-name bleed at lower ranks). Idempotent
— skips if `converted/.done` exists.

`build_candidate.dart` (Phase 1, no API cost) runs the per-corpus
loaders, dedupes case-insensitive across sources, fills source-deducible
tags (gender / language_ethnicity / race per corpus), marks the rest as
sentinels, and writes
`tools/generate_names/.cache/name_database.candidate.json`. The
candidate sits in `.cache/` (gitignored) on purpose — it's a large
intermediate build artifact, not something to commit or ship.

`classify.dart` (Phase 2) reads the slim file, batches names to the
LLM to fill the sentinel fields, and writes `tools/generate_names/data/
name_database.tagged.json`. A final Phase 3 (`emit_dart.dart`) then
emits the const-baked Dart file the package compiles in. Per-batch
progress at `tools/generate_names/.cache/.classify_progress.json` lets
a failed run resume without re-billing; the file persists after success,
so re-runs exit early — delete it manually to force a re-classify.

### Useful flags

- `--limit=N` (`classify.dart`): cap at the first N batches. Use this
  for a small smoke run (e.g. `--limit=2`) before paying for the full
  pass.
- `--batch-size=N` (`classify.dart`): names per request (default 100).
- `--model=MODEL` (`classify.dart`): override model id (default
  `grok-4.3`).

## Human review

Before committing the generated `name_database.tagged.json` and the
emitted `name_database_data.dart`, sample 50–100 entries and eyeball
for absurd tag combinations (e.g. "Mary" tagged allure=5), accidental
cultural insensitivity, and false cognates. The README in
`memory-bank/name_datasets/` lists the corpora used.

## Provider

Uses Grok 4.3 (xAI) by default with `reasoning_effort: "none"` and
strict JSON-schema responses. Classification is easier than generation
and Grok handles tag assignment well at lower per-token cost than the
frontier reasoning models. To switch providers, edit the constants at
the top of `classify.dart` (`_apiUrl`, `_defaultModel`, header auth).
