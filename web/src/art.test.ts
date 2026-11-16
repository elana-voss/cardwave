// pictureOr: a picture that does not come, or comes as a stub, gives its place to its stand-in; art stays.
// With `stubs: true` (the tab's round) a stub stays too: only a failure gives way.
import { expect, test } from "vitest";
import { pictureOr } from "./art";
import { el } from "./dom";

/** A picture in a box, as it comes with `width` × `width` pixels, or fails where `width` is null. */
function came(width: number | null, stubs = false): HTMLElement {
  const box = el("div");
  const shown = pictureOr(el("img", { src: "x.png" }), () => el("span", { className: "stand-in" }), { stubs });
  box.append(shown);
  if (width === null) shown.dispatchEvent(new Event("error"));
  else {
    Object.defineProperties(shown, { naturalWidth: { value: width }, naturalHeight: { value: width } });
    shown.dispatchEvent(new Event("load"));
  }
  return box;
}

test("a picture that fails or is a stub gives way to its stand-in; art stays", () => {
  expect([came(null), came(1), came(64)].map((box) => box.firstElementChild!.tagName)).toEqual(["SPAN", "SPAN", "IMG"]);
});

test("with stubs kept, only a picture that fails gives way", () => {
  expect([came(null, true), came(1, true), came(64, true)].map((box) => box.firstElementChild!.tagName)).toEqual(["SPAN", "IMG", "IMG"]);
});
