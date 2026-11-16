// What the search panel says when the server's search fails: the failure, never "Nothing found".
import { expect, test, vi } from "vitest";

vi.mock("../api/client", () => ({
  cardThumbnailUrl: () => "",
  findAll: async () => {
    throw new Error("the server is not answering");
  },
  getVoice: async () => ({ voices: [], languages: [] }),
}));
vi.mock("../account", () => ({ account: async () => ({ local: true }), elsewhere: false }));

test("a search the server failed says so, not that nothing was found", async () => {
  const { searchButton } = await import("./search-panel");
  const place = searchButton("x");
  document.body.append(place);
  place.querySelector("button")!.click();
  const field = document.querySelector<HTMLInputElement>(".search-panel input, input")!;
  field.value = "zzzqq";
  field.dispatchEvent(new Event("input", { bubbles: true }));
  await vi.waitFor(() => expect(document.body.textContent).toContain("The server is not answering"));
  expect(document.body.textContent).not.toContain("Nothing found");
});
