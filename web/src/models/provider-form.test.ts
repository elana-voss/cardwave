// What provider-form.ts decides without a browser: which models a model's field offers for what was typed into
// it, and what a failed model test says.
import { expect, test, vi } from "vitest";
import { testModel } from "../api/client";
import { modelName, modelTest, offering } from "./provider-form";

vi.mock("../api/client", async (real) => ({ ...(await real<object>()), testModel: vi.fn() }));

test("a model's field offers those whose ID holds every word typed, so “deepseek flash” finds the model a whole-string search missed", () => {
  const models = ["deepseek/deepseek-chat", "deepseek/deepseek-chat-v3.1-flash", "google/gemini-2.5-flash"];
  const offer = offering(() => models);
  // Two words narrow on their own, in the ID's order or not, where the whole string with its space matched nothing.
  expect(offer("deepseek flash")).toEqual(["deepseek/deepseek-chat-v3.1-flash"]);
  expect(offer("flash deepseek")).toEqual(["deepseek/deepseek-chat-v3.1-flash"]);
  // A single word still narrows as it did, whatever its case; spaces around and between count for nothing.
  expect(offer("DeepSeek")).toEqual(["deepseek/deepseek-chat", "deepseek/deepseek-chat-v3.1-flash"]);
  expect(offer("  flash  ")).toEqual(["deepseek/deepseek-chat-v3.1-flash", "google/gemini-2.5-flash"]);
  // Nothing typed offers all.
  expect(offer("")).toEqual(models);
});

test("a model is named as models.dev names it, else by its ID's last part in words", () => {
  expect(modelName("gpt-4o", { "gpt-4o": "GPT-4o" })).toBe("GPT-4o");
  expect(modelName("mistralai/mistral-small-4-119b-2603")).toBe("Mistral Small 4 119b 2603");
  expect(modelName("tide_1")).toBe("Tide 1");
});

test("a model of This computer failing its test names no key or address, which it has not", async () => {
  vi.mocked(testModel).mockRejectedValue(new Error("The AI sent no text"));
  const told = (own: boolean) =>
    new Promise<string>((done) => {
      const check = modelTest(() => !check.asking() && done(check.failed()));
      check.ask({ base_url: "http://127.0.0.1:8480/v1", model: "test-model" }, own);
    });
  expect(await told(false)).toMatch(/key/);
  const own = await told(true);
  expect(own).toMatch(/^The test failed: .*download/);
  expect(own).not.toMatch(/key|address/);
});

test("a model of This computer given up on as too slow names no key or address either", () => {
  vi.mocked(testModel).mockReturnValue(new Promise(() => {}));
  const check = modelTest(() => {});
  check.ask({ base_url: "http://127.0.0.1:8480/v1", model: "test-model" }, true);
  check.giveUp("It took too long");
  expect(check.failed()).toMatch(/download/);
  expect(check.failed()).not.toMatch(/key|address/);
});
