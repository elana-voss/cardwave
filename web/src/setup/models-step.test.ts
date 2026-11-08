// Whom first run's step 2 begins with (`storedFor`): the stored provider, else the one added last in Settings while
// no chat model is chosen, else none, and step 1 is shown.
import { expect, test } from "vitest";
import type { EntryView } from "../api/generated/EntryView";
import type { ProviderView } from "../api/generated/ProviderView";
import { storedFor } from "./models-step";

const entry = (id: number, base_url: string, own_name: string | null = null): EntryView => ({ id, name: "x", own_name, base_url, has_key: true, key_end: "4f2a", workflow: null, folder: null });
const list = (providers: EntryView[]) => ({ providers, kinds: [], own: [] });

test("first run begins with the provider added last when no chat model is chosen, else the stored one, else none", () => {
  const added = list([entry(1, "https://one.test/v1"), entry(2, "https://two.test/v1", "Mine")]);
  expect(storedFor(null, added)).toEqual({ base_url: "https://two.test/v1", name: "Mine", has_key: true, key_end: "4f2a" });
  const stored = { base_url: "https://one.test/v1", model: "m", has_key: false, key_end: null, name: null, worker_model: null } as unknown as ProviderView;
  expect(storedFor(stored, added)).toBe(stored);
  expect(storedFor(null, list([]))).toBeNull();
  expect(storedFor(null, undefined)).toBeNull();
});

test("a provider that only makes the pictures is not the one first run begins with", () => {
  const added = { ...list([entry(1, "https://one.test/v1"), entry(2, "http://127.0.0.1:8188")]), kinds: [{ kind: "images" as const, provider_id: 2, model: "m", thinking: "", gone: false }] };
  expect(storedFor(null, added)?.base_url).toBe("https://one.test/v1");
  expect(storedFor(null, { ...added, providers: [entry(2, "http://127.0.0.1:8188")] })).toBeNull();
});
