import { readFileSync } from "node:fs";
import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// "Make a character together": Create's New character offers it, the opening's questions have Next alone, the kinds six
// pills and More, the questions after them all their buttons. The pretend model answers what a step asks; a test
// holds a step back, or fails it, with `page.route` on `/api/interview/step`. Each test starts anew: `beforeEach`
// lets the kept interview go. Past it the read-back, whose lines `lines` fixes; the writing runs on the pretend model.
test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const next = (page: Page) => button(page, "Next");
const WANTED = "Someone who listens";
/** The English words of each interview text's id, as en.interview.ftl has them. */
const WORDS = new Map(
  readFileSync(new URL("../../web/src/language/en.interview.ftl", import.meta.url), "utf8")
    .split("\n")
    .map((line) => /^interview-(\S+) = (.*)$/.exec(line))
    .filter((found) => found !== null)
    .map((found) => [found[1], found[2]]),
);

/** Through the opening's four questions to the kinds. */
async function toKinds(page: Page): Promise<void> {
  await page.goto("/#/interview");
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await expect(page.getByText("When would you turn to it?")).toBeVisible();
  await button(page, "Late at night").click();
  await next(page).click();
  await expect(page.getByText("What would you want then?")).toBeVisible();
  await page.locator(".ask .pill").first().click();
  await next(page).click();
  await expect(page.getByText("What should it be?")).toBeVisible();
}

const SENTENCE = "She listens before she speaks.";
const OTHER = "She is there at the same time each evening.";
const READ_BACK = { lines: [{ sentence: SENTENCE, words: WANTED, gap: false }, { sentence: OTHER, words: "", gap: true }], questions: [0, null], guesses: [false, true] };

/** The read-back's lines are `READ_BACK`; answers how many were asked for. */
async function lines(page: Page): Promise<() => number> {
  let asked = 0;
  await page.route("**/api/interview/read-back", async (route) => {
    asked += 1;
    await route.fulfill({ json: READ_BACK });
  });
  return () => asked;
}

/** To the read-back, past the kinds by "Just make it". */
async function toReadBack(page: Page): Promise<void> {
  await toKinds(page);
  await next(page).click();
  await button(page, "Just make it").click();
  await expect(page.getByText("Here is what I understood.")).toBeVisible();
}

const pressed = (page: Page, name: string) => expect(button(page, name).first()).toHaveAttribute("aria-pressed", "true");

/** Fails the write with `body` where given, else lets it through; answers the bodies sent. */
async function writes(page: Page, body: object | null, persona?: string[]): Promise<Record<string, unknown>[]> {
  const sent: Record<string, unknown>[] = [];
  await page.route("**/api/interview/write", async (route) => {
    sent.push(route.request().postDataJSON());
    if (body) return route.fulfill({ status: 400, json: body });
    if (!persona) return route.continue();
    const response = await route.fetch();
    return route.fulfill({ response, json: { ...(await response.json()), persona } });
  });
  return sent;
}

test.beforeAll(async ({ request }) => {
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status()).toBe(200);
});

test.beforeEach(async ({ request }) => {
  expect((await request.put("/api/unsaved/interview", { data: { text: "" } })).ok()).toBe(true);
});

test("Create's line opens the opening: a free field, where the answers go, Next alone and off until something is said", async ({ page }) => {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "New character" }).click();
  await page.getByRole("link", { name: /^Make a character together/ }).click();
  await expect(page).toHaveURL(/#\/interview$/);
  await expect(page.locator("h1")).toHaveText("Make a character together");
  await expect(page.locator(".ask .hint")).toHaveText(/^Your answers go to .+ to write the character\.$/);
  await expect(page.locator(".ask-acts button")).toHaveText(["Next"]);
  await expect(next(page)).toBeDisabled();
  await page.getByLabel("Your answer").fill(WANTED);
  await expect(next(page)).toBeEnabled();
});

test("a model on this computer has the opening say the answers stay", async ({ page }) => {
  await page.route("**/api/interview", async (route) => {
    const response = await route.fetch();
    await route.fulfill({ response, json: { ...(await response.json()), goes_to: null } });
  });
  await page.goto("/#/interview");
  await expect(page.locator(".ask .hint")).toHaveText("Your answers stay on this computer.");
});

test("several picks add up, and the thread keeps what was said", async ({ page }) => {
  await page.goto("/#/interview");
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await button(page, "Late at night").click();
  await button(page, "Any time").click();
  await expect(page.locator('.ask .pill[aria-pressed="true"]')).toHaveText(["Any time"]);
  await expect(page.locator(".msg.me")).toHaveText([WANTED]);
});

test("the kinds show six, two picked, a third off, and More adds the rest and goes", async ({ page }) => {
  await toKinds(page);
  await expect(page.locator(".ask .pill")).toHaveCount(6);
  const off = page.locator(".ask .pill").nth(5);
  await expect(page.locator('.ask .pill[aria-pressed="true"]')).toHaveCount(2);
  await expect(off).toBeDisabled();
  await expect(page.locator(".ask-acts button")).toHaveText(["Next"]);
  await button(page, "More kinds").click();
  await expect(button(page, "More kinds")).toHaveCount(0);
  expect(await page.locator(".ask .pill").count()).toBeGreaterThan(6);
});

test("after the kinds a question has all its buttons; Skip stands in grey, Back asks again", async ({ page }) => {
  await toKinds(page);
  await next(page).click();
  await expect(page.locator(".ask-acts button")).toHaveText(["Next", "Skip", "I don't know", "Back", "Just make it"]);
  const asked = await page.locator(".msg:not(.me)").last().textContent();
  await button(page, "Skip").click();
  await expect(page.locator(".msg.me.c-grey, .msg.me .c-grey").last()).toHaveText("Skip");
  await button(page, "Back").click();
  await expect(page.locator(".msg:not(.me)").last()).toHaveText(asked!);
});

test("a question on its way shows the three dots with the answer; failed, it says so, Try again goes on", async ({ page }) => {
  await page.goto("/#/interview");
  let hold = true;
  let release = () => {};
  await page.route("**/api/interview/step", async (route) => {
    if (hold) {
      await new Promise<void>((done) => (release = done));
      await route.fulfill({ status: 502, json: { code: "internal", error: "the model did not answer", details: {} } });
    } else await route.fallback();
  });
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await expect(page.getByRole("status", { name: "Writing the next question" })).toBeVisible();
  await expect(page.locator(".msg.me")).toHaveText([WANTED]);
  release();
  await expect(page.getByRole("alert")).toHaveText("Something went wrong in Cardwave. Try again.");
  await expect(page.locator(".msg.me")).toHaveText([WANTED]);
  hold = false;
  await button(page, "Try again").click();
  await expect(page.getByText("When would you turn to it?")).toBeVisible();
});

test("Just make it after a failed step keeps its answer and ends the questions", async ({ page }) => {
  await page.goto("/#/interview");
  await page.route(
    "**/api/interview/step",
    (route) => (JSON.stringify(route.request().postDataJSON().action).includes("end_after") ? route.fallback() : route.fulfill({ status: 502, json: { code: "internal", error: "no", details: {} } })),
  );
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await button(page, "Just make it").click();
  await expect(page.locator(".msg.me")).toHaveText([WANTED]);
  await expect(page.locator(".ask")).toHaveCount(0);
});

test("an interview left comes back with its answers and what was being typed", async ({ page }) => {
  await page.goto("/#/interview");
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await button(page, "Late at night").click();
  await page.getByLabel("In your own words").fill("sort of");
  await page.goto("/#/generator");
  await expect(page.locator("h1")).toHaveText("Character generator");
  await page.goto("/#/interview");
  await expect(page.locator(".msg.me")).toHaveText([WANTED]);
  await expect(button(page, "Late at night")).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByLabel("In your own words")).toHaveValue("sort of");
});

/** Answers the next step with what the server said, changed by `change`. */
async function nextStep(page: Page, change: (interview: Record<string, unknown>) => void): Promise<void> {
  await page.route("**/api/interview/step", async (route) => {
    const response = await route.fetch();
    const interview = await response.json();
    change(interview);
    return route.fulfill({ response, json: interview });
  }, { times: 1 });
}

test("an interview kept without its seed starts anew", async ({ page }) => {
  await page.goto("/#/interview");
  await page.getByLabel("Your answer").fill(WANTED);
  await nextStep(page, (interview) => {
    interview.seed = "";
  });
  await next(page).click();
  await expect(button(page, "Late at night")).toBeVisible();
  await page.goto("/#/generator");
  await expect(page.locator("h1")).toHaveText("Character generator");
  await page.goto("/#/interview");
  await expect(page.getByLabel("Your answer")).toHaveValue("");
  await expect(page.locator(".msg.me")).toHaveCount(0);
});

test("an interview kept with its texts as English starts anew", async ({ page }) => {
  await page.goto("/#/interview");
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await expect(button(page, "Late at night")).toBeVisible();
  // As an interview kept before its texts went as ids: each question and choice its English.
  await page.route("**/api/unsaved/interview", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    const response = await route.fetch();
    const kept = JSON.parse((await response.json()).text);
    const english = (text: { id: string }) => WORDS.get(text.id);
    kept.interview.log = kept.interview.log.map((entry: { question: { id: string } }) => ({ ...entry, question: english(entry.question) }));
    kept.interview.asking.question = english(kept.interview.asking.question);
    kept.interview.asking.choices = kept.interview.asking.choices.map(english);
    return route.fulfill({ response, json: { text: JSON.stringify(kept) } });
  });
  await page.goto("/#/generator");
  await expect(page.locator("h1")).toHaveText("Character generator");
  await page.goto("/#/interview");
  await expect(page.getByLabel("Your answer")).toHaveValue("");
  await expect(page.locator(".msg.me")).toHaveCount(0);
});

test("the question how it treats you has its pills, none picked, no free line and Next off", async ({ page }) => {
  await toKinds(page);
  const text = (id: string) => ({ id, said: [] });
  const choices = ["pick-neither", "pick-as-a-man", "pick-as-a-woman"].map(text);
  const treat = { slot: "treat", question: text("ask-treat"), choices, multi: false, probe: false };
  await nextStep(page, (interview) => {
    interview.asking = treat;
  });
  await next(page).click();
  await expect(page.getByText("How should the character see you: as a man, as a woman, or neither?")).toBeVisible();
  await expect(button(page, "As a man")).toHaveAttribute("aria-pressed", "false");
  await expect(page.getByLabel("In your own words")).toHaveCount(0);
  await expect(next(page)).toBeDisabled();
  await expect(button(page, "Skip")).toBeVisible();
  await button(page, "As a man").click();
  await button(page, "As a woman").click();
  await expect(page.locator('.ask .pill[aria-pressed="true"]')).toHaveText(["As a woman"]);
});

test("leaving while a step runs hangs up", async ({ page }) => {
  await page.goto("/#/interview");
  const hung = new Promise<void>((done) => {
    void page.route("**/api/interview/step", () => {});
    page.on("requestfailed", (request) => {
      if (request.url().endsWith("/api/interview/step")) done();
    });
  });
  await page.getByLabel("Your answer").fill(WANTED);
  await next(page).click();
  await expect(page.getByRole("status", { name: "Writing the next question" })).toBeVisible();
  await page.goto("/#/generator");
  await hung;
});

test("Settings › Advanced has the line Interview style, Tree at first, and the choice sets what the interview asks", async ({ page, request }) => {
  await page.goto("/#/settings/advanced");
  const line = page.getByRole("group", { name: "Make a character together" });
  await expect(line.getByRole("button", { name: "Tree" })).toHaveAttribute("aria-pressed", "true");
  await line.getByRole("button", { name: "Cloud" }).click();
  await expect(line.getByRole("button", { name: "Cloud" })).toHaveAttribute("aria-pressed", "true");
  expect((await (await request.get("/api/interview")).json()).interview.style).toBe("cloud");
  await line.getByRole("button", { name: "Tree" }).click();
  await expect(line.getByRole("button", { name: "Tree" })).toHaveAttribute("aria-pressed", "true");
});

test("the read-back comes with the dots; Remove strikes a line and Keep takes it back, Change opens its field", async ({ page }) => {
  let hold = (_: unknown) => {};
  const held = new Promise((go) => (hold = go));
  await page.route("**/api/interview/read-back", async (route) => {
    await held;
    await route.fulfill({ json: READ_BACK });
  });
  await toKinds(page);
  await next(page).click();
  await button(page, "Just make it").click();
  await expect(page.locator(".typing")).toBeVisible();
  hold(null);
  await expect(page.getByText(SENTENCE)).toBeVisible();
  await expect(page.getByText(`you said: “${WANTED}”`)).toBeVisible();
  const first = page.locator(".readback > *").first();
  await expect(first.locator('.pill[aria-pressed="true"]')).toHaveCount(0);
  await first.getByRole("button", { name: "Remove" }).click();
  await expect(first.locator("s")).toHaveText(SENTENCE);
  await first.getByRole("button", { name: "Remove" }).click();
  await expect(first.locator("s")).toHaveCount(0);
  await expect(first.locator('.pill[aria-pressed="true"]')).toHaveCount(0);
  await first.getByRole("button", { name: "Remove" }).click();
  await first.getByRole("button", { name: "Keep" }).click();
  await expect(first.locator("s")).toHaveCount(0);
  await expect(first.locator('.pill[aria-pressed="true"]')).toHaveText(["Keep"]);
  await first.getByRole("button", { name: "Change" }).click();
  await expect(first.getByLabel("Your own sentence")).toBeFocused();
  await expect(page.locator(".readback > *").nth(1).getByRole("button", { name: "That's not it" })).toBeDisabled();
});

test("That's not it asks again with the answer it had; Back keeps the list, Next brings a new one with the choices gone", async ({ page }) => {
  await lines(page);
  await toReadBack(page);
  const first = page.locator(".readback > *").first();
  await first.getByRole("button", { name: "Remove" }).click();
  await first.getByRole("button", { name: "That's not it" }).click();
  await expect(page.locator(".interview .ask textarea")).toHaveValue(WANTED);
  await expect(page.locator(".ask-acts button")).toHaveText(["Next", "Back"]);
  await button(page, "Back").click();
  await expect(first.locator("s")).toHaveText(SENTENCE);
  await first.getByRole("button", { name: "That's not it" }).click();
  await page.locator(".interview .ask textarea").fill("Someone who argues");
  let hold = (_: unknown) => {};
  const held = new Promise((go) => (hold = go));
  await page.route("**/api/interview/not-it", async (route) => {
    await held;
    const response = await route.fetch();
    const made = await response.json();
    expect(made.interview.log[0].free).toBe("Someone who argues");
    await route.fulfill({ response, json: { ...made, read_back: { lines: [{ sentence: "She argues.", words: "Someone who argues", gap: false }], questions: [0], guesses: [false] } } });
  });
  await next(page).click();
  await expect(page.locator(".typing")).toBeVisible();
  hold(null);
  await expect(page.getByText("She argues.")).toBeVisible();
  await expect(page.locator(".readback s")).toHaveCount(0);
  await expect(page.locator(".readback > *")).toHaveCount(1);
});

test("That's not it on the kinds line asks by the kinds' pills, the old two picked, and sends what is picked now", async ({ page }) => {
  await page.route("**/api/interview/read-back", (route) => route.fulfill({ json: { lines: [{ sentence: SENTENCE, words: "", gap: false }], questions: [3], guesses: [true] } }));
  await toReadBack(page);
  await button(page, "That's not it").click();
  const picked = page.locator('.ask .pill[aria-pressed="true"]');
  await expect(picked).toHaveCount(2);
  await expect(page.locator(".ask-acts button")).toHaveText(["Next", "Back"]);
  await picked.first().click();
  await page.locator('.ask .pill[aria-pressed="false"]').first().click();
  const now = await picked.allTextContents();
  let log: { slot: string; picks: { id: string }[] }[] = [];
  await page.route("**/api/interview/not-it", async (route) => {
    const response = await route.fetch();
    log = (await response.json()).interview.log;
    await route.fulfill({ response });
  });
  await next(page).click();
  await expect.poll(() => log.length).toBeGreaterThan(3);
  expect(log[3].slot).toBe("kinds");
  expect(log[3].picks.map((pick) => WORDS.get(pick.id)).sort()).toEqual(now.sort());
});

test("That's not it on a line answered by pills asks by its pills, and the picks stay picks", async ({ page }) => {
  await page.route("**/api/interview/read-back", (route) => route.fulfill({ json: { lines: [{ sentence: SENTENCE, words: "Late at night", gap: false }], questions: [1], guesses: [false] } }));
  await toReadBack(page);
  await button(page, "That's not it").click();
  await expect(page.locator('.ask .pill[aria-pressed="true"]')).toHaveText(["Late at night"]);
  await expect(page.locator(".ask-acts button")).toHaveText(["Next", "Back"]);
  let log: { picks: unknown[] }[] = [];
  await page.route("**/api/interview/not-it", async (route) => {
    const response = await route.fetch();
    log = (await response.json()).interview.log;
    await route.fulfill({ response });
  });
  await next(page).click();
  await expect.poll(() => log.length).toBeGreaterThan(1);
  expect(log[1].picks).toEqual([{ id: "pick-late-at-night", said: [] }]);
});

test("the private list opens in place, sends what was answered, and Skip all closes it with nothing kept", async ({ page }) => {
  await lines(page);
  const sent = await writes(page, { code: "internal" });
  await toReadBack(page);
  const line = page.getByRole("button", { name: /Anything you want in your character's world/ });
  await line.click();
  await expect(page.locator("section h2")).toHaveText("Anything you want in your character's world, or never?");
  await expect(line).toHaveCount(0);
  const rows = page.locator("section .fld");
  await rows.nth(1).getByRole("button", { name: "No", exact: true }).click();
  await rows.nth(1).getByLabel("Never").check();
  await page.getByLabel("Anything else you want, or never want").fill(" no spiders ");
  await button(page, "Make the character").click();
  await expect(page.locator("[role=alert]")).toBeVisible();
  const list = sent[0].private as { open: boolean; rows: { never: boolean; answer: string }[]; free: string };
  expect(list.open).toBe(true);
  expect(list.rows).toHaveLength(1);
  expect(list.rows[0]).toMatchObject({ answer: "no", never: true });
  expect(list.free).toBe("no spiders");
  await button(page, "Skip all").click();
  await expect(line).toBeVisible();
  await line.click();
  await expect(rows.nth(1).getByRole("button", { name: "Don't know" })).toHaveAttribute("aria-pressed", "true");
});

test("while writing the list is greyed with Stop, which goes back to it; a failure stands red over the button, the answers kept", async ({ page }) => {
  await lines(page);
  await toReadBack(page);
  await page.locator(".readback > *").first().getByRole("button", { name: "Remove" }).click();
  let hold = (_: unknown) => {};
  const held = new Promise((go) => (hold = go));
  await page.route("**/api/interview/write", async (route) => {
    await held;
    await route.abort();
  });
  await button(page, "Make the character").click();
  await expect(button(page, "Writing the character…")).toBeDisabled();
  await expect(page.locator(".faded[aria-disabled=true] .readback")).toBeVisible();
  await button(page, "Stop").click();
  await expect(button(page, "Make the character")).toBeEnabled();
  await page.unroute("**/api/interview/write");
  hold(null);
  await writes(page, { code: "internal" });
  await button(page, "Make the character").click();
  await expect(page.locator(".c-danger[role=alert]")).toBeVisible();
  await expect(page.locator(".readback s")).toHaveText(SENTENCE);
  await expect(button(page, "Make the character")).toBeEnabled();
});

test("a refusal offers another model for this writing, and writing without the topic opens the private list", async ({ page }) => {
  await lines(page);
  const sent = await writes(page, { code: "model_declined", details: { model: "Some model" } });
  await toReadBack(page);
  await button(page, "Make the character").click();
  await expect(page.getByText("Some model declined to write this.")).toBeVisible();
  await button(page, "Try another model").click();
  const other = page.getByRole("menuitem", { name: /^pretend-chat-mini · / });
  await expect(page.getByRole("menuitem", { name: /^pretend-chat · / })).toHaveCount(0);
  await other.click();
  await expect.poll(() => sent.length).toBe(2);
  expect((sent[0] as { other_model: unknown }).other_model).toBeNull();
  expect((sent[1] as { other_model: { model: string } }).other_model.model).toBe("pretend-chat-mini");
  await button(page, "Write it without that topic").click();
  await expect(page.locator("section h2")).toBeVisible();
  await expect(button(page, "Make the character")).toBeEnabled();
});

test("written, the new character's page opens with the facts to add to the persona; Add makes them part of it, and the field is forgotten", async ({ page, request }) => {
  await lines(page);
  await writes(page, null, ["Works late", "Has a cat"]);
  await toReadBack(page);
  await button(page, "Make the character").click();
  await expect(page).toHaveURL(/#\/library\/\d+/);
  const box = page.getByRole("dialog", { name: "Add what you said about yourself to your persona?" });
  await expect(box.getByRole("checkbox")).toHaveCount(2);
  await box.getByLabel("Has a cat").uncheck();
  await box.getByRole("button", { name: "Add", exact: true }).click();
  await expect(box).toHaveCount(0);
  await expect(page.getByText(/^Added to “.+”\.$/)).toBeVisible();
  const personas = (await (await request.get("/api/personas")).json()) as { description: string }[];
  expect(personas.some((one) => one.description.includes("Works late") && !one.description.includes("Has a cat"))).toBe(true);
  expect((await (await request.get("/api/unsaved/interview")).json())?.text ?? "").toBe("");
});

test("Not now adds nothing, and no facts bring no dialog", async ({ page, request }) => {
  await lines(page);
  await writes(page, null, ["Walks by the river"]);
  await toReadBack(page);
  await button(page, "Make the character").click();
  const box = page.getByRole("dialog", { name: "Add what you said about yourself to your persona?" });
  await box.getByRole("button", { name: "Not now" }).click();
  await expect(box).toHaveCount(0);
  const personas = (await (await request.get("/api/personas")).json()) as { description: string }[];
  expect(personas.some((one) => one.description.includes("river"))).toBe(false);
  await page.unroute("**/api/interview/write");
  await writes(page, null, []);
  await toReadBack(page);
  await button(page, "Make the character").click();
  await expect(page).toHaveURL(/#\/library\/\d+/);
  await expect(page.locator("h1").first()).toBeVisible();
  await expect(box).toHaveCount(0);
});

test("coming back finds the read-back as it was, with no second read-back asked for", async ({ page }) => {
  const asked = await lines(page);
  await toReadBack(page);
  const first = page.locator(".readback > *").first();
  await first.getByRole("button", { name: "Remove" }).click();
  await page.getByRole("button", { name: /Anything you want in your character's world/ }).click();
  await page.locator("section .fld").first().getByRole("button", { name: "Yes", exact: true }).click();
  await page.goto("/#/chats");
  await page.goto("/#/interview");
  await expect(first.locator("s")).toHaveText(SENTENCE);
  await expect(page.locator("section .fld").first().getByRole("button", { name: "Yes", exact: true })).toHaveAttribute("aria-pressed", "true");
  expect(asked()).toBe(1);
});

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the interview", async ({ page }) => {
        await page.goto("/#/interview");
        await page.getByLabel("Your answer").fill(WANTED);
        await next(page).click();
        await expect(page.getByText("When would you turn to it?")).toBeVisible();
        await button(page, "Late at night").click();
        await page.evaluate(() => (document.activeElement as HTMLElement | null)?.blur());
        await picture(page, `interview-${width}-${theme}`);
      });
    });
  }
}
