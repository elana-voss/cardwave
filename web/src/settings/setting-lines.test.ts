// A settings switch pressed while another change of its runner is on its way goes back, as nothing was sent.
import { expect, test, vi } from "vitest";
import { changeSettings } from "../api/client";
import { noticeBox, oneAtATime } from "../dom";
import { settingSwitch } from "./setting-lines";

vi.mock("../api/client", () => ({ changeSettings: vi.fn() }));

test("the second switch of a runner shows what the server holds when its change was dropped", async () => {
  let answer!: (settings: unknown) => void;
  vi.mocked(changeSettings).mockReturnValueOnce(new Promise((done) => (answer = done)) as never);
  const attempt = oneAtATime(noticeBox());
  const watch = settingSwitch(attempt, "Watch", "watch");
  const recycle = settingSwitch(attempt, "Recycle", "recycle");
  const held = { card_folder: { watch: true, recycle: false } };
  watch.show({ card_folder: { watch: false, recycle: false } } as never);
  recycle.show(held as never);
  watch.toggle.checked = true;
  watch.toggle.dispatchEvent(new Event("change"));
  recycle.toggle.checked = true;
  recycle.toggle.dispatchEvent(new Event("change"));
  await Promise.resolve();
  await Promise.resolve();
  expect(recycle.toggle.checked).toBe(false);
  expect(changeSettings).toHaveBeenCalledTimes(1);
  answer(held);
  await vi.waitFor(() => expect(watch.toggle.disabled).toBe(false));
  expect(watch.toggle.checked).toBe(true);
});
