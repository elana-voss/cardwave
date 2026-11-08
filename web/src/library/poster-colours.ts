// What a poster takes from its picture, on the picture's pixels alone, no DOM: the crop (`cropOf`), which end is busier
// (`readCrop`, `flips`) and the colour rule (`colours`), whose steps the page "Cardwave Posters" (docs/design.md) lists.
// Black, white, the warm hue range and the vivid saturation and lightness are the only constants; every other colour
// comes from the picture. Pixels are RGBA, as a canvas gives them.

export type Rgb = [number, number, number];
/** An end of a poster. */
export type End = "top" | "foot";

/** The part of a picture a poster shows, in the picture's pixels, and that as `object-position`. */
export interface Crop {
  sx: number;
  sy: number;
  sw: number;
  sh: number;
  position: string;
}
/** A colour group of the picture's crop. */
interface Bucket {
  colour: Rgb;
  weight: number;
  L: number;
  C: number;
}
/** What the crop's two ends are like. */
interface Band {
  busy: number;
  median: number;
}
export interface Reading {
  buckets: Bucket[];
  total: number;
  top: Band;
  foot: Band;
}
export interface Colours {
  fade: Rgb;
  title: Rgb;
  tagline: Rgb;
  light: boolean;
}

/** A poster's shape, width to height. */
const SHAPE = 2 / 3;
/** How strongly the crop is pulled to the picture's centre. */
const PULL = 0.08;
/** How many times as busy the title's end must be for the layout to flip. */
const FLIP = 1.3;
/** The size of the sample the colours are read from. */
export const SAMPLE = { width: 40, height: 60 };
/** The longer side of the sample the crop is found on. */
export const CROP_SAMPLE = 96;
/** The share of the rows that is a poster's end. */
const END_ROWS = 0.38;
const WHITE: Rgb = [255, 255, 255];
const BLACK: Rgb = [0, 0, 0];
/** The design system's colours, for a card without a picture. */
export const NO_PICTURE: Colours = { fade: [17, 17, 17], title: [255, 255, 255], tagline: [156, 156, 156], light: false };

const linear = (value: number) => {
  const part = value / 255;
  return part <= 0.04045 ? part / 12.92 : ((part + 0.055) / 1.055) ** 2.4;
};
const luminance = ([r, g, b]: Rgb) => 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);

/** CIELAB lightness and chroma of an sRGB colour, D65 white. */
export function lab([red, green, blue]: Rgb): { L: number; C: number } {
  const [r, g, b] = [linear(red), linear(green), linear(blue)];
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const fx = f((r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047);
  const fy = f(r * 0.2126 + g * 0.7152 + b * 0.0722);
  const fz = f((r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883);
  return { L: 116 * fy - 16, C: Math.hypot(500 * (fx - fy), 200 * (fy - fz)) };
}

/** WCAG contrast of two colours. */
export function contrast(one: Rgb, other: Rgb): number {
  const [a, b] = [luminance(one), luminance(other)];
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

const mix = (from: Rgb, to: Rgb, share: number) => from.map((value, at) => Math.round(value + (to[at] - value) * share)) as Rgb;

/** A colour as `#RRGGBB`. */
export const hex = (colour: Rgb) => `#${colour.map((value) => value.toString(16).padStart(2, "0")).join("").toUpperCase()}`;

function hue(colour: Rgb): number {
  const [r, g, b] = colour.map((value) => value / 255);
  const [most, least] = [Math.max(r, g, b), Math.min(r, g, b)];
  const range = most - least;
  if (!range) return 0;
  const sextant = most === r ? ((g - b) / range) % 6 : most === g ? (b - r) / range + 2 : (r - g) / range + 4;
  return (sextant * 60 + 360) % 360;
}

function fromHsl(h: number, s: number, l: number): Rgb {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const sector: Rgb[] = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]];
  return sector[Math.floor(h / 60) % 6].map((value) => Math.round((value + m) * 255)) as Rgb;
}

/**
 * The most detailed part of a picture of `wide` by `high` pixels, of a poster's shape: all of its other side, along
 * this one where its sum of differences between neighbours is highest, with a slight pull to the centre.
 * `pixels` is the picture scaled to `width` by `height`.
 */
export function cropOf(pixels: Uint8ClampedArray, width: number, height: number, wide: number, high: number): Crop {
  const grey = new Float32Array(width * height);
  for (let at = 0; at < grey.length; at++) grey[at] = 0.2126 * pixels[at * 4] + 0.7152 * pixels[at * 4 + 1] + 0.0722 * pixels[at * 4 + 2];
  const alongWidth = wide / high > SHAPE;
  const length = alongWidth ? width : height;
  const window = Math.round(alongWidth ? height * SHAPE : width / SHAPE);
  if (window >= length - 1) return { sx: 0, sy: 0, sw: wide, sh: high, position: "50% 50%" };
  const profile = new Float32Array(length);
  for (let y = 1; y < height; y++) {
    for (let x = 1; x < width; x++) {
      const at = y * width + x;
      profile[alongWidth ? x : y] += Math.abs(grey[at] - grey[at - 1]) + Math.abs(grey[at] - grey[at - width]);
    }
  }
  const span = length - window;
  const sums = Array.from({ length: span + 1 }, (_, start) => profile.subarray(start, start + window).reduce((sum, part) => sum + part, 0));
  // A picture alike everywhere has no detail to go to: only the pull counts.
  const most = Math.max(...sums) || 1;
  let best = 0;
  let bestScore = -1;
  sums.forEach((sum, start) => {
    const score = sum / most + PULL * (1 - Math.abs(start - span / 2) / (span / 2));
    if (score > bestScore) {
      bestScore = score;
      best = start;
    }
  });
  const along = best / span;
  const percent = `${(along * 100).toFixed(0)}%`;
  return alongWidth
    ? { sx: (wide - high * SHAPE) * along, sy: 0, sw: high * SHAPE, sh: high, position: `${percent} 50%` }
    : { sx: 0, sy: (high - wide / SHAPE) * along, sw: wide, sh: wide / SHAPE, position: `50% ${percent}` };
}

/** The middle of a picture of `wide` by `high` pixels, of a poster's shape, where its pixels cannot say better. */
export function centreCrop(wide: number, high: number): Crop {
  const sw = Math.min(wide, high * SHAPE);
  const sh = Math.min(high, wide / SHAPE);
  return { sx: (wide - sw) / 2, sy: (high - sh) / 2, sw, sh, position: "50% 50%" };
}

/** Reads the crop, scaled to `SAMPLE`: its colour groups, by the top 4 bits of red, green and blue, and its two ends. */
export function readCrop(pixels: Uint8ClampedArray): Reading {
  const { width, height } = SAMPLE;
  const total = width * height;
  const lightness = new Float32Array(total);
  const groups = new Map<number, [number, number, number, number]>();
  for (let at = 0; at < total; at++) {
    const [r, g, b] = [pixels[at * 4], pixels[at * 4 + 1], pixels[at * 4 + 2]];
    lightness[at] = lab([r, g, b]).L;
    const key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    const group = groups.get(key) ?? [0, 0, 0, 0];
    group[0] += r;
    group[1] += g;
    group[2] += b;
    group[3]++;
    groups.set(key, group);
  }
  const buckets = [...groups.values()].map(([r, g, b, weight]) => {
    const colour = [r / weight, g / weight, b / weight].map(Math.round) as Rgb;
    return { colour, weight, ...lab(colour) };
  });
  const band = (from: number, to: number): Band => {
    let busy = 0;
    let pairs = 0;
    const rows: number[] = [];
    for (let y = from; y < to; y++) {
      for (let x = 0; x < width; x++) {
        const at = y * width + x;
        rows.push(lightness[at]);
        if (x && y) {
          busy += Math.abs(lightness[at] - lightness[at - 1]) + Math.abs(lightness[at] - lightness[at - width]);
          pairs++;
        }
      }
    }
    rows.sort((one, other) => one - other);
    return { busy: busy / pairs, median: rows[rows.length >> 1] };
  };
  return { buckets, total, top: band(0, Math.round(height * END_ROWS)), foot: band(Math.round(height * (1 - END_ROWS)), height) };
}

/** Whether a title at its home end moves to the other one, as its home is so much busier. */
export const flips = (reading: Reading, home: End) => reading[home].busy > FLIP * reading[home === "top" ? "foot" : "top"].busy;

/** The colour rule, for a title at `end`. */
export function colours(reading: Reading, end: End, wanted: { vivid?: boolean; warm?: boolean }): Colours {
  const { buckets, total } = reading;
  const light = reading[end].median >= 60;
  const heaviest = (which: (bucket: Bucket) => boolean) => buckets.filter(which).sort((one, other) => other.weight - one.weight)[0] as Bucket | undefined;
  const extreme = () => [...buckets].sort((one, other) => (light ? other.L - one.L : one.L - other.L))[0];
  const common = heaviest((bucket) => (light ? bucket.L > 75 : bucket.L < 25));
  const base = common && common.weight >= total * 0.01 ? common : extreme();
  const fade = light ? mix(base.colour, WHITE, 0.55) : mix(base.colour, BLACK, 0.45);
  const score = (bucket: Bucket) => bucket.C ** 1.5 * Math.sqrt(bucket.weight);
  const strong = buckets.filter((bucket) => bucket.L > 15 && bucket.L < 90 && bucket.C > 20 && bucket.weight >= total * 0.004).sort((one, other) => score(other) - score(one));
  const warm = wanted.warm ? strong.filter((bucket) => hue(bucket.colour) >= 15 && hue(bucket.colour) <= 65) : [];
  const fadeL = lab(fade).L;
  let accent = (warm[0] ?? strong[0])?.colour ?? heaviest((bucket) => Math.abs(bucket.L - fadeL) >= 50)?.colour ?? (light ? BLACK : WHITE);
  if (wanted.vivid && lab(accent).C >= 8) accent = fromHsl(hue(accent), 0.85, light ? 0.38 : 0.56);
  const toward = light ? BLACK : WHITE;
  let title = accent;
  for (let step = 0; step < 20 && contrast(title, fade) < 6; step++) title = mix(title, toward, 0.14);
  return { fade, title, tagline: light ? mix(accent, BLACK, 0.78) : mix(accent, WHITE, 0.82), light };
}
