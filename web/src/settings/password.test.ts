// What password.ts decides without a browser: what its dialog asks the server for.
import { expect, test } from "vitest";
import { asked } from "./password";

test("the dialog asks for what its kind says, and not for two passwords that differ", () => {
  expect(asked("on", { password: "harbour", repeat: "harbour" })).toEqual({ password: "harbour" });
  expect(asked("change", { current: "old", password: "harbour", repeat: "harbour" })).toEqual({ current: "old", password: "harbour" });
  expect(asked("off", { current: "old" })).toEqual({ current: "old" });
  expect(() => asked("on", { password: "harbour", repeat: "harbor" })).toThrow("The two passwords differ.");
});
