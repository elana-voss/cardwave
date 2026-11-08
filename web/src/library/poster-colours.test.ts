import { describe, expect, it } from "vitest";
import { colours, contrast, cropOf, flips, lab, NO_PICTURE, readCrop, type Rgb } from "./poster-colours";

/** A picture's pixels, each from `colour(x, y)`. */
function pixels(wide: number, high: number, colour: (x: number, y: number) => Rgb): Uint8ClampedArray {
  const out = new Uint8ClampedArray(wide * high * 4);
  for (let y = 0; y < high; y++) {
    for (let x = 0; x < wide; x++) out.set([...colour(x, y), 255], (y * wide + x) * 4);
  }
  return out;
}
const noise = (x: number, y: number): Rgb => ((x * 7 + y * 13) % 3 === 0 ? [255, 255, 255] : [0, 0, 0]);
const grey: Rgb = [90, 90, 90];
/** The reading of a poster's sample whose every pixel is `colour(x, y)`. */
const read = (colour: (x: number, y: number) => Rgb) => readCrop(pixels(40, 60, colour));

describe("the crop", () => {
  it("goes to the most detailed part of a tall picture", () => {
    const crop = cropOf(pixels(32, 96, (x, y) => (y > 60 ? noise(x, y) : grey)), 32, 96, 320, 960);
    expect(crop.sw).toBe(320);
    expect(crop.sh).toBeCloseTo(480);
    expect(crop.sy).toBeGreaterThan(240);
    expect(crop.position).toMatch(/^50% /);
  });

  it("goes to the most detailed part of a wide picture", () => {
    const crop = cropOf(pixels(96, 48, (x, y) => (x < 30 ? noise(x, y) : grey)), 96, 48, 960, 480);
    expect(crop.sh).toBe(480);
    expect(crop.sw).toBeCloseTo(320);
    expect(crop.sx).toBeLessThan(160);
  });

  it("is pulled to the centre where the picture is alike everywhere", () => {
    const crop = cropOf(pixels(96, 48, () => grey), 96, 48, 960, 480);
    expect(crop.position).toBe("50% 50%");
    expect(crop.sx).toBeCloseTo((960 - 320) / 2);
  });

  it("takes all of a picture of the poster's shape", () => {
    expect(cropOf(pixels(64, 96, noise), 64, 96, 640, 960)).toEqual({ sx: 0, sy: 0, sw: 640, sh: 960, position: "50% 50%" });
  });
});

describe("the flip", () => {
  it("happens only where the title's end is over 1.3 times as busy as the other", () => {
    const busyTop = read((x, y) => (y < 20 ? noise(x, y) : grey));
    expect(flips(busyTop, "top")).toBe(true);
    expect(flips(busyTop, "foot")).toBe(false);
    expect(flips(read(noise), "top")).toBe(false);
  });
});

describe("the colour rule", () => {
  it("fades a dark end from the heaviest dark colour, 45% toward black", () => {
    const made = colours(read(() => [40, 20, 20]), "top", {});
    expect(made.light).toBe(false);
    expect(made.fade).toEqual([22, 11, 11]);
  });

  it("fades a light end from the heaviest light colour, 55% toward white", () => {
    const made = colours(read(() => [220, 220, 200]), "top", {});
    expect(made.light).toBe(true);
    expect(made.fade).toEqual([239, 239, 230]);
  });

  it("reads the lightness of the end the title sits at", () => {
    const halves = read((_x, y) => (y < 30 ? [230, 230, 230] : [20, 20, 20]));
    expect(colours(halves, "top", {}).light).toBe(true);
    expect(colours(halves, "foot", {}).light).toBe(false);
  });

  it("takes the accent from the picture's most vivid colour and keeps the title at contrast 6", () => {
    const made = colours(read((_x, y) => (y % 4 === 0 ? [20, 60, 200] : [10, 10, 10])), "top", {});
    expect(lab(made.title).C).toBeGreaterThan(8);
    expect(contrast(made.title, made.fade)).toBeGreaterThanOrEqual(6);
    expect(made.title[2]).toBeGreaterThan(made.title[0]);
  });

  it("prefers a warm hue in a warm design", () => {
    const picture = read((_x, y) => (y % 4 === 0 ? [20, 60, 240] : y % 4 === 1 ? [200, 140, 40] : [10, 10, 10]));
    const plain = colours(picture, "top", {}).title;
    expect(plain[2]).toBeGreaterThan(plain[0]);
    const warm = colours(picture, "top", { warm: true }).title;
    expect(warm[0]).toBeGreaterThan(warm[2]);
  });

  it("sets a vivid design's hue to full strength", () => {
    const picture = read((_x, y) => (y % 4 === 0 ? [120, 70, 60] : [10, 10, 10]));
    const plain = lab(colours(picture, "top", {}).title).C;
    expect(lab(colours(picture, "top", { vivid: true }).title).C).toBeGreaterThan(plain);
  });

  it("uses the picture's own light tone on a colourless dark picture, no colour from outside", () => {
    const made = colours(read((_x, y) => (y % 5 === 0 ? [200, 200, 200] : [15, 15, 15])), "top", { vivid: true });
    expect(made.title[0]).toBe(made.title[1]);
    expect(made.title[0]).toBeGreaterThanOrEqual(200);
  });

  it("mixes the tagline from the accent, 82% toward white on a dark fade", () => {
    const made = colours(read(() => [10, 10, 10]), "top", {});
    expect(Math.min(...made.tagline)).toBeGreaterThan(200);
  });

  it("has the design system's colours for a card without a picture", () => {
    expect(NO_PICTURE).toEqual({ fade: [17, 17, 17], title: [255, 255, 255], tagline: [156, 156, 156], light: false });
  });
});
