"""Writes crates/cw-voice/voices/<id>.wav, the native speakers' recordings that come with the app (`crates/cw-voice/src/lib.rs`,
`NATIVE`), as fetched: the French ones from Kyutai's `tts-voices` (`cml-tts/fr`, cleaned by Kyutai), the others
from CML-TTS on Hugging Face (`ylacombe/cml-tts`, a row of its split `dev`, by way of the datasets server, as its
files are Parquet only). All CML-TTS, CC BY 4.0. Each was picked with a voice's pitch in mind, one lower and one
higher per language, among clips of 10 to 15 seconds whose words were read well. Run once; the files are committed.

    python tools/voices.py
"""

import json
import os
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "crates", "cw-voice", "voices")
KYUTAI = "https://huggingface.co/kyutai/tts-voices/resolve/323332d33f997de8394f24a193e1a76df720e01a/cml-tts/fr/{}_enhanced.wav"
ROWS = "https://datasets-server.huggingface.co/rows?dataset=ylacombe/cml-tts&config={}&split=dev&offset={}&length=1"

# id: (language config, row of `dev`, its speaker) or the French file's name.
VOICES = {
    "lena": ("german", 16, 3277),
    "jonas": ("german", 9, 138),
    "giulia": ("italian", 6, 11247),
    "marco": ("italian", 17, 642),
    "beatriz": ("portuguese", 47, 9056),
    "tiago": ("portuguese", 10, 5417),
    "lucia": ("spanish", 14, 2592),
    "mateo": ("spanish", 9, 1075),
    "elise": "577_394_000070-0001",
    "hugo": "4724_3731_000031-0001",
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, source in VOICES.items():
        if isinstance(source, str):
            url = KYUTAI.format(source)
        else:
            config, row, speaker = source
            found = json.load(urllib.request.urlopen(ROWS.format(config, row)))["rows"][0]["row"]
            assert found["speaker_id"] == speaker, (name, found["speaker_id"])
            url = found["audio"][0]["src"]
        data = urllib.request.urlopen(url).read()
        assert data[:4] == b"RIFF", name
        open(os.path.join(OUT, name + ".wav"), "wb").write(data)
        print(name, len(data))


if __name__ == "__main__":
    main()
