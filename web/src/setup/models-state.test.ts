// First run's step 2: its lead line, when its main button is greyed and its clock of 8 and 30 seconds.
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { greyed, lead, workClock } from "./models-state";

const done = { open: false, slow: false, chat: "gemma-4", chatFailed: false, workerFailed: false, noList: false };

test("the lead line says the work, that it is slow, done, one failed, or nothing fits, and says to go on only where the main button can", () => {
  expect(lead({ ...done, open: true })).toBe("Cardwave is choosing your models and trying them out…");
  expect(lead({ ...done, open: true, slow: true })).toBe("Cardwave is choosing your models and trying them out… Still asking your provider.");
  expect(lead(done)).toBe("Your models are ready. Change any of them now or later in Settings.");
  expect(lead({ ...done, workerFailed: true })).toBe("One model didn't answer. Pick another, or go on and set it later.");
  // While the chat model failed the main button waits: the lead does not say to go on.
  expect(lead({ ...done, chatFailed: true })).toBe("The chat model didn't answer. Pick another, or try again.");
  expect(lead({ ...done, chat: "" })).toBe("Cardwave found no fitting model. Choose one, or enter the provider's address in Settings.");
  // Without a list or picks, nothing was found wanting: the provider did not answer.
  expect(lead({ ...done, chat: "", noList: true })).toBe("Your provider didn't answer. Try again, or choose a model.");
  expect(lead({ ...done, noList: true })).toBe("One model didn't answer. Pick another, or go on and set it later.");
});

test("the main button is greyed while work is open, without a chat model, and while the chat model failed; not for the helper", () => {
  expect(greyed(done)).toBe(false);
  expect(greyed({ ...done, open: true })).toBe(true);
  expect(greyed({ ...done, chat: "" })).toBe(true);
  expect(greyed({ ...done, chatFailed: true })).toBe(true);
  expect(greyed({ ...done, workerFailed: true })).toBe(false);
});

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

test("the clock says slow after 8 s of open work and gives up after 30 s; work done stops it", () => {
  const changed = vi.fn();
  const late = vi.fn();
  const clock = workClock(changed, late);
  clock.run(true);
  vi.advanceTimersByTime(7_999);
  expect(clock.slow()).toBe(false);
  vi.advanceTimersByTime(1);
  expect(clock.slow()).toBe(true);
  expect(changed).toHaveBeenCalledTimes(1);
  // Work that goes on does not start it anew.
  clock.run(true);
  vi.advanceTimersByTime(22_000);
  expect(late).toHaveBeenCalledTimes(1);
  // Done: not slow, and nothing more is told.
  clock.run(false);
  expect(clock.slow()).toBe(false);
  clock.run(true);
  vi.advanceTimersByTime(5_000);
  clock.run(false);
  vi.advanceTimersByTime(60_000);
  expect(late).toHaveBeenCalledTimes(1);
  expect(changed).toHaveBeenCalledTimes(1);
});

test("work the user starts anew (“Change”, “Try again”) while work is open gets its own 8 s and 30 s", () => {
  const changed = vi.fn();
  const late = vi.fn();
  const clock = workClock(changed, late);
  clock.run(true);
  vi.advanceTimersByTime(20_000);
  expect(clock.slow()).toBe(true);
  clock.restart();
  clock.run(true);
  expect(clock.slow()).toBe(false);
  vi.advanceTimersByTime(20_000);
  expect(late).not.toHaveBeenCalled();
  vi.advanceTimersByTime(10_000);
  expect(late).toHaveBeenCalledTimes(1);
});
