#!/usr/bin/env python3
"""Convert philipperemy/name-dataset pickles to per-country JSON.

The upstream corpus ships gzipped Python pickles. The Dart Phase 1
loader can't parse those natively, so this one-shot script pivots the
two pickles into per-country JSON files the Dart loader reads.

Run from the repo root (or anywhere — the script resolves its own
location):

    python app/tools/generate_names/philipperemy_to_json.py

Idempotent — exits early if memory-bank/name_datasets/philipperemy/
converted/.done exists. Delete that marker to re-convert.

Output:
    memory-bank/name_datasets/philipperemy/converted/<COUNTRY>_first.json
    memory-bank/name_datasets/philipperemy/converted/<COUNTRY>_last.json

Each file is a JSON array sorted by rank within that country, capped at
TOP_N_PER_COUNTRY to keep file sizes manageable.

    [
      {"name": "Mary", "gender": "F", "rank": 1},
      {"name": "Linda", "gender": "F", "rank": 2},
      ...
    ]

Last-name files omit the gender field.
"""

import gzip
import json
import pickle
import sys
from collections import defaultdict
from pathlib import Path


TOP_N_PER_COUNTRY = 100


def _load_pickle(path):
    with gzip.open(path, 'rb') as f:
        return pickle.load(f)


def _max_key(d):
    if not d:
        return None
    return max(d, key=d.get)


def _pivot(names_dict, include_gender):
    per_country = defaultdict(list)
    for name, info in names_dict.items():
        ranks = info.get('rank') or {}
        gender = _max_key(info.get('gender') or {}) if include_gender else None
        for country, rank in ranks.items():
            record = {'name': name, 'rank': rank}
            if include_gender:
                record['gender'] = gender
            per_country[country].append(record)
    return {
        country: sorted(entries, key=lambda x: x['rank'])[:TOP_N_PER_COUNTRY]
        for country, entries in per_country.items()
    }


def _write_per_country(per_country, out_dir, suffix):
    for country, entries in per_country.items():
        out = out_dir / f'{country}_{suffix}.json'
        out.write_text(
            json.dumps(entries, ensure_ascii=False),
            encoding='utf-8',
        )


def main():
    script_dir = Path(__file__).resolve().parent
    # script_dir = <repo>/app/tools/generate_names → three parents up = repo root.
    repo_root = script_dir.parent.parent.parent
    philipperemy = repo_root / 'memory-bank' / 'name_datasets' / 'philipperemy'
    v3 = philipperemy / 'names_dataset' / 'v3'
    out_dir = philipperemy / 'converted'
    marker = out_dir / '.done'

    if marker.exists():
        print(f'[skip] {marker} exists. Delete to re-convert.')
        return 0

    if not v3.exists():
        print(
            f'[error] {v3} missing — run dataset_fetch.dart first.',
            file=sys.stderr,
        )
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)

    print('[load] first_names.pkl.gz', flush=True)
    first_names = _load_pickle(v3 / 'first_names.pkl.gz')
    print(f'       {len(first_names):,} names', flush=True)

    print('[pivot] grouping first names by country', flush=True)
    first_per_country = _pivot(first_names, include_gender=True)
    del first_names

    print(
        f'[write] {len(first_per_country)} first-name country files',
        flush=True,
    )
    _write_per_country(first_per_country, out_dir, 'first')
    del first_per_country

    print('[load] last_names.pkl.gz', flush=True)
    last_names = _load_pickle(v3 / 'last_names.pkl.gz')
    print(f'       {len(last_names):,} names', flush=True)

    print('[pivot] grouping last names by country', flush=True)
    last_per_country = _pivot(last_names, include_gender=False)
    del last_names

    print(
        f'[write] {len(last_per_country)} last-name country files',
        flush=True,
    )
    _write_per_country(last_per_country, out_dir, 'last')

    marker.write_text('done', encoding='utf-8')
    print(f'[done] {marker}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
