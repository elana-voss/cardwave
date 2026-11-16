// What the browser keeps, where it refuses: no call throws, and what is read is "nothing kept".
import { afterEach, expect, test, vi } from "vitest";
import { keepOverReload, remember, remembered, takeKept } from "./storage";

afterEach(() => vi.unstubAllGlobals());

test("a note kept over the reload is read once", () => {
  keepOverReload("note", "1");
  expect(takeKept("note")).toBe("1");
  expect(takeKept("note")).toBeNull();
});

test("a browser that refuses storage keeps nothing and throws nothing", () => {
  const refuse = () => {
    throw new DOMException("refused", "SecurityError");
  };
  const refusing = { getItem: refuse, setItem: refuse, removeItem: refuse };
  vi.stubGlobal("localStorage", refusing);
  vi.stubGlobal("sessionStorage", refusing);
  expect(() => remember("choice", "1")).not.toThrow();
  expect(remembered("choice")).toBeNull();
  expect(() => keepOverReload("note", "1")).not.toThrow();
  expect(takeKept("note")).toBeNull();
});
