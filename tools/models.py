"""Writes crates/cw-provider/providers/models.dev.json.gz, models.dev's whole list as fetched, by which first run picks the models
and a model's kinds are told where its provider does not say them (`crates/cw-provider/src/models_dev.rs`, which
refreshes it at most once a day where the app runs). It is written anew as a whole and not kept by hand.

    python tools/models.py <api.json>

<api.json> is https://models.dev/api.json, fetched beforehand.
"""

import gzip
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WHOLE = os.path.join(ROOT, "crates", "cw-provider", "providers", "models.dev.json.gz")


def main():
    raw = open(sys.argv[1], "rb").read()
    # mtime 0: the same list writes the same file.
    with open(WHOLE, "wb") as out:
        out.write(gzip.compress(raw, 9, mtime=0))


if __name__ == "__main__":
    main()
