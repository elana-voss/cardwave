// The UI's words for the server's error answers (errors.ts): from the code and its details, never the server's sentence.
import { afterEach, expect, it } from "vitest";
import { errorWords, failureWords } from "./errors";
import { useLanguage } from "./language";

afterEach(() => useLanguage("en"));

it("words an error by its code and details, not by the server's sentence", () => {
  expect(errorWords(400, { code: "lorebook_trashed", error: "the server's own words", details: { name: "Harbour" } })).toBe("The lorebook “Harbour” is in the Trash; restore it to use it.");
  expect(errorWords(404, { code: "not_found", error: "no such card_version", details: { what: "card_version" } })).toBe("There is no such card version. It may have been deleted.");
  expect(errorWords(400, { code: "not_readable", error: "x", details: { what: "picture" } })).toBe("The picture is not a PNG, JPEG or WebP.");
  expect(errorWords(403, { code: "owner_only", error: "x", details: { action: "use its files" } })).toBe("Only this computer's account can use its files.");
});

it("words a reply's failure from its code, a provider's own text as its detail", () => {
  const refused = { code: "provider_refused", error: "the model's server answered 429: slow down", details: { whose: "model_server", refusal: "busy", status: 429, reason: "slow down" } } as const;
  expect(failureWords(refused)).toBe(errorWords(400, refused));
  expect(failureWords(refused)).toBe("The provider has no credit left or is busy: try again later.");
  const other = { ...refused, details: { ...refused.details, refusal: "other", status: 418 } };
  expect(failureWords(other)).toContain("slow down");
  // Too long is what was sent (a whole chat, too), not a message the user can shorten.
  const tooLong = { ...refused, details: { ...refused.details, refusal: "too_long", status: 400 } };
  expect(failureWords(tooLong)).toBe("The model was sent more than it can read at once: pick a model that reads more in Settings › Models.");
  expect(failureWords({ code: "internal", error: "the server failed to save the reply", details: {} })).toBe("Something went wrong in Cardwave. Try again.");
});

it("words an answer without a code it knows by its status", () => {
  expect(errorWords(500, null)).toBe(errorWords(500, { code: "internal", error: "", details: {} }));
  expect(errorWords(400, { error: "the server's own words" })).toBe(errorWords(400, { code: "request_failed", error: "", details: {} }));
});

it("words an error in the language in use", () => {
  useLanguage("xx", "error-chat-busy = Antwort läuft\n");
  expect(errorWords(409, { code: "chat_busy", error: "a reply is being generated", details: {} })).toBe("Antwort läuft");
});

it("closes a provider's own text with a full stop before what follows it", () => {
  const fault = { code: "provider_refused", error: "x", details: { whose: "model_server", refusal: "fault", status: 500, reason: "upstream exploded" } } as const;
  expect(failureWords(fault)).toBe("The provider had a fault on its side: upstream exploded. Try again later.");
  expect(failureWords({ ...fault, details: { ...fault.details, reason: "It broke!" } })).toBe("The provider had a fault on its side: It broke! Try again later.");
});


it("says a refused key as refused, not as a provider that did not answer", () => {
  const refused = { code: "answered", error: "x", details: { whose: "model_server", said: "did not take the key", status: "401", reason: "" } } as const;
  expect(failureWords(refused)).toBe("The provider did not take the key.");
  expect(failureWords({ ...refused, details: { whose: "model_server", status: "502", reason: "" } })).toBe("The AI's provider answered 502. Try again later.");
});
