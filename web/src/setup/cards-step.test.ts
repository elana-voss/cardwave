// First run's step "Cards": the folder the server offers is shown and "Continue" takes it; "Skip" goes on
// without it, though one is shown; without an offer, "Skip" alone. The server is a stand-in (`../api/client`).
import { beforeEach, expect, test, vi } from "vitest";
import { getOfferedCardFolder } from "../api/client";
import { cardsStep } from "./cards-step";

vi.mock("../api/client", () => ({ getOfferedCardFolder: vi.fn() }));

beforeEach(() => localStorage.clear());

const step = () => cardsStep(() => document.body, async () => true);

test("the folder offered is shown and taken by “Import from this folder”", async () => {
  vi.mocked(getOfferedCardFolder).mockResolvedValue("C:/Users/you/Documents");
  const cards = step();
  await cards.offer();
  expect(cards.node.textContent).toContain("C:/Users/you/Documents");
  expect(cards.go.textContent).toBe("Import from this folder");
  expect(cards.skip.hidden).toBe(false);
  expect(cards.node.textContent).toContain("Change");
  cards.take(true);
  expect(cards.chosen()).toBe("C:/Users/you/Documents");
  // Held until setup ends, also through a reload.
  expect(step().chosen()).toBe("C:/Users/you/Documents");
});

test("“Skip” goes on without the folder shown", async () => {
  vi.mocked(getOfferedCardFolder).mockResolvedValue("C:/Users/you/Documents");
  const cards = step();
  await cards.offer();
  cards.take(false);
  expect(cards.chosen()).toBeNull();
  expect(step().chosen()).toBeNull();
});

test("without a folder offered, only “Skip” is there", async () => {
  vi.mocked(getOfferedCardFolder).mockResolvedValue(null);
  const cards = step();
  await cards.offer();
  expect(cards.go.textContent).toBe("Skip");
  expect(cards.skip.hidden).toBe(true);
  expect(cards.node.textContent).toContain("Choose folder");
  cards.take(true);
  expect(cards.chosen()).toBeNull();
});
