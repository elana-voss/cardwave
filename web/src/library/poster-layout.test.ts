import { describe, expect, it } from "vitest";
import { cutTagline, freeBands, keepOffFaces, layoutTitle, type Placing, type Sides } from "./poster-layout";

/** At 100 px every letter or space is 50 px wide. */
const width = (line: string) => line.length * 50;
const box = { width: 200, height: 300, room: 170, largest: 0.3, lineHeight: 1 };

describe("the title", () => {
  it("keeps a short title on one line, as large as its design allows", () => {
    expect(layoutTitle("Rain", width, box)).toEqual({ size: 60, lines: ["Rain"], cut: false });
  });

  it("breaks between words where that gives the largest size", () => {
    const made = layoutTitle("Winter Harbour Lights", width, box);
    expect(made.lines).toEqual(["Winter", "Harbour", "Lights"]);
    expect(made.size).toBeCloseTo((0.34 * 300) / 3);
  });

  it("is never higher than about a third of the poster", () => {
    const made = layoutTitle("Aa Bb Cc", width, { ...box, largest: 1, lineHeight: 2 });
    expect(made.size * made.lines.length * 2).toBeLessThanOrEqual(0.34 * 300 + 0.01);
  });

  it("is cut at a word with an ellipsis after three lines at its smallest size", () => {
    const made = layoutTitle("The Keeper of the Last Lighthouse on the Northern Coast of the Grey and Windy Sea Beyond the Old Harbour Wall", width, box);
    expect(made.cut).toBe(true);
    expect(made.lines).toHaveLength(3);
    expect(made.lines[2].endsWith("…")).toBe(true);
    expect(made.size).toBeCloseTo(0.063 * 200);
    expect((width(made.lines[2]) * made.size) / 100).toBeLessThanOrEqual(170);
  });

  it("cuts a word wider than the room at the smallest size with an ellipsis, and ends there", () => {
    const made = layoutTitle("Oh Pneumonoultramicroscopicsilicovolcanoconiosis Again", width, box);
    expect(made.cut).toBe(true);
    expect(made.lines[made.lines.length - 1]).toMatch(/^Pneumono.*…$/);
    for (const line of made.lines) expect((width(line) * made.size) / 100).toBeLessThanOrEqual(box.room);
  });

  it("does not try every break of a very long title", () => {
    let asked = 0;
    layoutTitle(Array(120).fill("word").join(" "), (line) => (asked++, width(line)), box);
    expect(asked).toBeLessThan(500);
  });
});

describe("the tagline", () => {
  it("stays as it is where it fits", () => {
    expect(cutTagline("A quiet night", () => true)).toBe("A quiet night");
  });

  it("is cut at a word with an ellipsis until it fits", () => {
    expect(cutTagline("One two three four", (text) => text.length <= 10)).toBe("One two…");
  });
});

describe("the free bands", () => {
  const whole = { sx: 0, sy: 0, sw: 100, sh: 150, position: "" };
  const picture = { width: 100, height: 150 };
  const size = { width: 100, height: 150 };

  it("blocks the rows of a face grown by 15%", () => {
    const { free } = freeBands([{ left: 0.25, top: 0.2, width: 0.5, height: 0.2 }], whole, picture, size);
    expect(free[0].from).toBe(0);
    expect(free[0].to).toBeCloseTo(30 - 4.5);
    expect(free[1].from).toBeCloseTo(60 + 4.5);
    expect(free[1].to).toBe(150);
  });

  it("merges faces that overlap", () => {
    const faces = [
      { left: 0, top: 0.2, width: 0.5, height: 0.2 },
      { left: 0.5, top: 0.3, width: 0.5, height: 0.2 },
    ];
    expect(freeBands(faces, whole, picture, size).free).toHaveLength(2);
  });

  it("drops a face outside the crop or under 1% of the poster", () => {
    expect(freeBands([{ left: 0.1, top: 0.1, width: 0.02, height: 0.02 }], whole, picture, size).free).toEqual([{ from: 0, to: 150 }]);
    const lower = { sx: 0, sy: 150, sw: 100, sh: 150, position: "" };
    expect(freeBands([{ left: 0.2, top: 0.1, width: 0.5, height: 0.2 }], lower, { width: 100, height: 300 }, size).boxes).toBe(0);
  });
});

describe("the face rule", () => {
  /** Text whose height at each end is given and, stacked, at each step; what it was told is written down. */
  function placing(need: Sides, stacked: number[]): Placing & { told: string[] } {
    const told: string[] = [];
    let swapped = false;
    let step = 0;
    return {
      told,
      need: () => (swapped ? { top: need.foot, foot: need.top } : need),
      swap: () => {
        swapped = true;
        told.push("swap");
      },
      stack: (band) => told.push(`stack ${band.from}`),
      stackedHeight: () => stacked[step],
      shrinkTitle: (room) => {
        step++;
        told.push(`shrink ${room}`);
      },
      dropTagline: (room) => {
        step++;
        told.push(`drop ${room}`);
      },
      titleAtFoot: () => told.push("foot"),
    };
  }
  const H = 300;
  const lowerHalfFree = [{ from: 100, to: 300 }];

  it("keeps the placing where the text is clear", () => {
    const place = placing({ top: 0, foot: 90 }, []);
    expect(keepOffFaces([{ from: 0, to: 50 }, { from: 200, to: 300 }], place, H)).toBe("clear");
    expect(place.told).toEqual([]);
  });

  it("swaps the ends where that clears the face", () => {
    const place = placing({ top: 150, foot: 0 }, []);
    expect(keepOffFaces(lowerHalfFree, place, H)).toBe("swapped");
    expect(place.told).toEqual(["swap"]);
  });

  it("stacks both in the largest free band, between two faces too", () => {
    const place = placing({ top: 60, foot: 60 }, [50]);
    const bands = [{ from: 0, to: 20 }, { from: 100, to: 220 }, { from: 280, to: 300 }];
    expect(keepOffFaces(bands, place, H)).toBe("stacked");
    expect(place.told).toEqual(["swap", "stack 100"]);
  });

  it("makes the title smaller, then drops the tagline, then sets the title over the face at the foot", () => {
    const bands = [{ from: 0, to: 80 }];
    expect(keepOffFaces(bands, placing({ top: 90, foot: 60 }, [99, 50]), H)).toBe("shrunk");
    expect(keepOffFaces(bands, placing({ top: 90, foot: 60 }, [99, 99, 50]), H)).toBe("dropped");
    const over = placing({ top: 90, foot: 60 }, [99, 99, 99]);
    expect(keepOffFaces(bands, over, H)).toBe("over");
    expect(over.told.at(-1)).toBe("foot");
    expect(over.told).toContain(`drop ${80 - 2 * 0.03 * H}`);
  });

  it("leaves the text where it is when the faces fill the poster", () => {
    const place = placing({ top: 90, foot: 60 }, []);
    expect(keepOffFaces([], place, H)).toBe("no-room");
    expect(place.told).toEqual(["swap", "swap"]);
  });
});
