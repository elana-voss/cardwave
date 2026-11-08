// What password.ts decides without a browser: what its dialog asks the server for, and the start screen's wait
// after too many wrong passwords.
import { afterEach, expect, test, vi } from "vitest";
import { asked, lockedElsewhere, passwordLine, startScreen, untilUnlocked } from "./password";
import { ApiError } from "../api/client";

afterEach(() => vi.useRealTimers());

test("the dialog asks for what its kind says, and not for two passwords that differ", () => {
  expect(asked("on", { password: "harbour", repeat: "harbour" })).toEqual({ password: "harbour" });
  expect(asked("change", { current: "old", password: "harbour", repeat: "harbour" })).toEqual({ current: "old", password: "harbour" });
  expect(asked("off", { current: "old" })).toEqual({ current: "old" });
  expect(() => asked("on", { password: "harbour", repeat: "harbor" })).toThrow("The two passwords differ.");
});

test("the wait after too many wrong passwords counts down and clears itself when it is over", async () => {
  vi.useFakeTimers();
  const refused = new ApiError(429, { code: "too_many_tries", error: "", details: { seconds: 3 } });
  const screen = startScreen("Mira", () => Promise.reject(refused));
  screen.querySelector("form")!.dispatchEvent(new Event("submit", { cancelable: true }));
  await vi.advanceTimersByTimeAsync(0);
  const note = () => screen.querySelector(".note")!.textContent;
  expect(note()).toBe("Too many wrong passwords. Try again in 3 seconds.");
  await vi.advanceTimersByTimeAsync(1000);
  expect(note()).toBe("Too many wrong passwords. Try again in 2 seconds.");
  await vi.advanceTimersByTimeAsync(2000);
  expect(note()).toBe("");
});

test("another account's device is told the app is locked on its computer, with no field, and goes on once it opens", async () => {
  vi.useFakeTimers();
  const screen = lockedElsewhere();
  expect(screen.querySelector("input")).toBeNull();
  expect(screen.textContent).toContain("Cardwave is locked on its computer. It opens here when it is unlocked there.");
  let locked = true;
  const opened = vi.fn();
  untilUnlocked(() => Promise.resolve({ locked }), opened);
  await vi.advanceTimersByTimeAsync(5000);
  expect(opened).not.toHaveBeenCalled();
  locked = false;
  await vi.advanceTimersByTimeAsync(5000);
  expect(opened).toHaveBeenCalledOnce();
});

test("the password line's buttons' spoken names hold their visible words", () => {
  for (const button of passwordLine("Password", () => document.body).node.querySelectorAll("button"))
    expect(button.ariaLabel ?? button.textContent).toContain(button.textContent);
});
