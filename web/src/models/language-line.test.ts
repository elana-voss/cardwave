// "Language the AI writes in": a language the server refused is not left in the field.
import { expect, test, vi } from "vitest";
import { changeSettings, getSettings, listLanguages } from "../api/client";
import { languageLine } from "./language-line";

vi.mock("../api/client", () => ({ changeSettings: vi.fn(), getSettings: vi.fn(), listLanguages: vi.fn() }));

test("a language that was not stored is not shown: the field goes back to the one stored", async () => {
  vi.mocked(listLanguages).mockResolvedValue([
    { code: "en", name: "English" },
    { code: "de", name: "Deutsch" },
  ] as never);
  vi.mocked(getSettings).mockResolvedValue({ language: "en", language_chosen: true } as never);
  vi.mocked(changeSettings).mockRejectedValue(new Error("offline"));
  const { node } = languageLine();
  document.body.append(node);
  await vi.waitFor(() => expect(node.querySelector<HTMLButtonElement>("button.selectbtn")?.disabled).toBe(false));
  const button = node.querySelector<HTMLButtonElement>("button.selectbtn")!;
  expect(button.textContent).toContain("English");
  button.click();
  [...document.querySelectorAll<HTMLElement>('[role="menuitemradio"]')].find((one) => one.textContent === "German")?.click();
  await vi.waitFor(() => expect(changeSettings).toHaveBeenCalled());
  await new Promise((done) => setTimeout(done, 20));
  expect(button.textContent).toContain("English");
});
