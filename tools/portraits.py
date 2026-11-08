"""Makes the screenshot spec's portraits once, on nano-gpt's image API, into e2e/portraits/<name>.jpg.

`python tools/portraits.py [name ...]` from ROOT makes the named portraits (all missing ones without names;
`--again` makes the named ones anew). Each is a 2:3 picture of one card's character (PORTRAITS: its art style,
palette, genre and look, so the library looks made by different people), scaled to 600 x 900 and saved as a JPEG of
about 50 KB (at most 55) with ImageMagick (`magick` on PATH). Prints the balance's change, the spend. Key from NANOGPT_API_KEY,
never printed. The pictures are committed; no test asks the provider (e2e/tests/99-screenshots.spec.ts reads them).
Model: MODEL, included in the nano-gpt subscription (the key cannot spend the balance); nano-gpt's terms give the
output to whoever asked for it. A picture with broken hands, faces or stray letters is made again with `--again`.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "e2e" / "portraits"
# Included in the nano-gpt subscription (100 pictures a day): no dollars spent.
MODEL = "z-image-turbo"
SIZE = "1024*1536"
IMAGES = "https://nano-gpt.com/api/v1/images"
BALANCE = "https://nano-gpt.com/api/check-balance"
# Every prompt ends so: one figure, nothing written, nothing borrowed.
TAIL = (
    " Upright portrait, one character, head and shoulders to waist, looking at the viewer, natural hands."
    " Original character, safe for work, no text, no letters, no watermark, no logo, no signature, no frame."
)

PORTRAITS = {
    "nyra": "Painterly digital fantasy illustration, visible brush strokes. A woman warden in her thirties with "
    "braided ash-blonde hair and a hooded moss-green cloak, holding a small lantern with a warm amber flame, in a "
    "frost-covered birch forest at dawn. Cool greens and silver, soft golden backlight.",
    "ilse": "Classical oil painting on canvas, thick impasto. A weathered sea captain woman in her late thirties with "
    "short copper hair, a scar over one eyebrow and a long navy coat, standing at a ship's rail at sunset, wind in "
    "her hair, a wry half-smile. Warm oranges and deep blues.",
    "aldous": "Loose watercolour illustration on textured paper, sepia and ochre washes with ink lines. An elderly "
    "man, about seventy-five, with round spectacles, white tufty hair and a tweed waistcoat, leaning over a desk of "
    "papers in a 1950s study lit by a green desk lamp, curious eyes.",
    "juniper": "Anime cel-shaded illustration, clean line art, flat bright shading. A cheerful young woman in her "
    "twenties with curly auburn hair tied up, flour on her cheek and a pastel apron, holding a fresh loaf of bread "
    "in a cosy kitchen at night. Soft pinks, cream and warm yellow light.",
    "k7": "Semi-realistic 3D render, cinematic lighting. A slender humanoid station robot with a smooth white and "
    "graphite shell and a softly glowing cyan visor for a face, a gentle tilted head, inside a dim space station "
    "corridor with violet lights and a window onto stars.",
    "ruth": "Ink drawing with flat colour, bold brush ink lines, limited palette of slate blue, grey and one amber "
    "accent. A Black woman detective in her forties with close-cropped hair, a rain-wet trench coat and a stern, "
    "tired look, under a street lamp in the rain at night.",
    "sable": "Retro comic book illustration, halftone dots, bold outlines, flat saturated colours. A young "
    "androgynous courier with a shaved undercut, goggles on their forehead, a dusty scarf and a patched backpack, in "
    "a ruined desert highway with a rusted sign post, orange sky and teal shadows.",
    "wren": "Soft pastel chalk illustration, gentle and airy. A young woman in a Regency-era empire-waist gown of pale "
    "lavender, dark hair in a loose updo with a ribbon, holding a folded fan, in a candle-lit ballroom with blurred "
    "dancers behind. Lilac, powder blue and pearl tones, a shy smile.",
    "hesk": "Gouache and linocut-style illustration, textured, folk-tale mood. An old woman herbalist of the marsh "
    "with long grey hair, a crooked knowing smile and a shawl stitched with dried herbs, holding a candle, reeds "
    "and mist behind her, a crow on her shoulder. Murky greens, plum and candle gold, slightly eerie but kind.",
    "hiro": "Vibrant flat vector illustration, clean shapes, subtle grain. A Japanese man in his fifties with a "
    "salt-and-pepper beard, a white headband and a navy cook's jacket, behind the counter of a tiny ramen stall at "
    "night, steam rising, plain red paper lanterns and a rainy street, no signs and no writing anywhere. Red, navy and warm orange.",
    "astra": "1970s science-fiction paperback cover art, airbrushed, grainy, retro-futurist. A South Asian woman "
    "starship navigator in her thirties with a dark bob haircut, wearing a burnt-orange turtleneck under a long cream "
    "cape-collared coat, a glowing star chart in her hand, a "
    "ringed planet and a sleek rocket behind her. Burnt orange, teal and cream.",
    "ember": "Storybook children's illustration, gouache, rounded friendly shapes. A small round red-orange dragon "
    "with stubby wings and big golden eyes, curled up on a hearthstone beside a crackling fireplace, a knitted "
    "blanket and a teacup nearby. Warm reds, browns and honey light, cosy.",
    "rowan": "Pencil sketch with a light watercolour wash. A traveller in their late twenties with short wavy brown "
    "hair, freckles and a calm, open face, wearing a simple travelling coat with a satchel strap, a river and "
    "willow trees faintly behind. Muted greens, browns and blue.",
}


def key() -> str:
    found = os.environ.get("NANOGPT_API_KEY")
    if not found:
        sys.exit("NANOGPT_API_KEY is not set")
    return found


def asked(url: str, body: dict | None = None, timeout: int = 300) -> dict:
    data = json.dumps(body or {}).encode()
    request = urllib.request.Request(url, data=data, headers={"x-api-key": key(), "Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(request, timeout=timeout) as answer:
        return json.load(answer)


def balance() -> float:
    return float(asked(BALANCE)["usd_balance"])


def picture_of(answer: dict) -> bytes:
    """The first picture of an answer: its base64 or its address."""
    first = answer["data"][0]
    if first.get("b64_json"):
        return base64.b64decode(first["b64_json"])
    with urllib.request.urlopen(first["url"], timeout=120) as got:
        return got.read()


def make(name: str, model: str, size: str) -> None:
    answer = asked(IMAGES, {"model": model, "prompt": PORTRAITS[name] + TAIL, "resolution": size, "n": 1})
    raw = OUT / f"{name}.download"
    raw.write_bytes(picture_of(answer))
    target = OUT / f"{name}.jpg"
    # 600 x 900, cropped to 2:3 from the middle; the quality ImageMagick finds for at most 55 KB.
    subprocess.run(["magick", str(raw), "-resize", "600x900^", "-gravity", "center", "-extent", "600x900", "-strip", "-define", "jpeg:extent=55KB", str(target)], check=True)
    raw.unlink()
    print(f"{name}: {target.stat().st_size // 1024} KB")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*")
    parser.add_argument("--again", action="store_true")
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--size", default=SIZE)
    args = parser.parse_args()
    unknown = [name for name in args.names if name not in PORTRAITS]
    if unknown:
        sys.exit(f"unknown: {unknown}")
    OUT.mkdir(parents=True, exist_ok=True)
    names = args.names or list(PORTRAITS)
    todo = [name for name in names if args.again or not (OUT / f"{name}.jpg").exists()]
    before = balance()
    for name in todo:
        try:
            make(name, args.model, args.size)
        except Exception as failed:  # One failed picture is told and the rest are made.
            print(f"{name}: failed: {failed}")
    print(f"spent {before - balance():.4f} dollars on {len(todo)} pictures")


if __name__ == "__main__":
    main()
