// What the user typed, put back into a screen made anew (typed.ts): also where the screen fills the field itself
// later, as the server answers, but not over what the user types after.
import { expect, test } from "vitest";
import { el } from "../dom";
import { putTyped } from "./typed";

const frames = () => new Promise((done) => setTimeout(done, 50));

test("typed text put back stays over the screen's own later fill, and yields to what the user types after", async () => {
  const field = el("input", { className: "key" });
  const node = el("section", {}, field);
  document.body.replaceChildren(node);
  putTyped(node, { fields: [["input.key@0", "sk-typed"]], focus: null });
  expect(field.value).toBe("sk-typed");
  // The server's answer comes and the screen fills the field.
  field.value = "";
  await frames();
  expect(field.value).toBe("sk-typed");
  field.value = "sk-new";
  field.dispatchEvent(new Event("input", { bubbles: true }));
  await frames();
  expect(field.value).toBe("sk-new");
});
