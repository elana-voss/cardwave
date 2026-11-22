// The side panel's number fields take digits alone (`wholeNumber`); Reply length's step (`replyStep`); whether Reply length is used, and why not (`replyLengthNote`). What the side panel's "Used in this reply" says of a reply besides its lorebook entries: its tool calls
// and what was saved to memory; how it looks is the browser tests'.
import { expect, onTestFinished, test } from "vitest";
import type { MessageView } from "../api/generated/MessageView";
import type { ChatLorebook } from "../api/generated/ChatLorebook";
import type { ChatView } from "../api/generated/ChatView";
import { bookSays, chatPanel, type PanelActions, replySteps, replyLengthNote, replyStep, usedFacts, usedReply, wholeNumber } from "./panel";
import { useLanguage } from "../language/language";

const reply = (more: Partial<MessageView>): MessageView => ({
  id: 1, parent_id: null, role: "assistant", speaker_id: null, content: "", complete: true, token_count: null, created_at: 0,
  swipes: [1], lore: [], memories: [], picture: false, tokens: 0, task_id: null, context: null, model: null, provider: null, times: null, sent: null, calls: [], attachments: [], broke_off: false,
  ...more,
});

test("a reply's tool calls and memories, each part there only where it has something, and no tokens", () => {
  const sent = { card: 300, persona: 20, memory: 0, lorebook: 40, history: 900 };
  const facts = usedFacts(
    reply({
      calls: [
        { tool: "dice", what: "2d6: 3 + 4 = 7", end: "done" },
        { tool: "read_web_page", what: "Lamp oil · example.com", end: "done" },
        { tool: "read_file", what: "notes/a.md", end: "failed" },
        { tool: "write_file", what: "plan.txt", end: "not_allowed" },
        { tool: "run_command", what: "ls", end: "stopped" },
        { tool: "lamp_tool", what: "", end: "done" },
      ],
      memories: ["The hearing moved to noon."],
      sent,
    }),
  );
  expect(facts).toEqual([
    {
      about: "Tools used",
      lines: [
        { text: "Dice · 2d6: 3 + 4 = 7" },
        { text: "Web page · Lamp oil · example.com" },
        { text: "Read file · notes/a.md", note: "failed" },
        { text: "Write file · plan.txt", note: "not allowed" },
        { text: "Run command · ls", note: "stopped" },
        { text: "lamp_tool" },
      ],
    },
    { about: "Saved to memory", lines: [{ text: "The hearing moved to noon." }] },
  ]);
  expect(usedFacts(reply({}))).toEqual([]);
});

test("the last reply is the one before the pictures it made, not a picture of its own", () => {
  const words = reply({ id: 1 });
  const pictures = [reply({ id: 2, picture: true }), reply({ id: 3, picture: true })];
  expect(usedReply({ messages: [words, ...pictures] } as ChatView)).toBe(words);
  const alone = reply({ id: 4, picture: true });
  expect(usedReply({ messages: [reply({ id: 5, role: "user" }), alone] } as ChatView)).toBe(alone);
});

test("with pictures after the last reply, the panel still tells the tools that reply called", () => {
  const panel = chatPanel({} as PanelActions);
  const chat = { reply_length: 350, code_mode: false, talk_pause: 4, talk_replies: 10, trashed: false, prompt_preset: "card" };
  const messages = [reply({ id: 1, calls: [{ tool: "make_picture", what: "a boat", end: "done" }] }), reply({ id: 2, picture: true })];
  const view = { chat, characters: [], messages, lorebooks: [], persona: null, asking: null, modes: [], model: null, thinks: false, tools: false } as unknown as ChatView;
  panel.show({ view, personas: [], library: [], prompts: [], personality: null, locked: false, talking: false, chosen: null });
  const line = [...panel.node.querySelectorAll<HTMLElement>(".item.entry")].find((item) => item.textContent?.includes("Tools used"));
  expect(line?.textContent).toContain("Make picture · a boat");
  expect(line?.closest<HTMLElement>(".panel-part")?.hidden).toBe(false);
});

test("a number field takes a whole number in digits, at least its least, and nothing else", () => {
  expect(wholeNumber(" 12 ", 1)).toBe(12);
  expect(wholeNumber("0", 0)).toBe(0);
  for (const wrong of ["0", "", "1e2", "0x10", "1.0", "+5", "-3", "two"]) expect(wholeNumber(wrong, 1)).toBeNull();
});

test("Reply length's steps are named as lengths of a reply, not of hair, in every language", () => {
  onTestFinished(() => useLanguage("en"));
  useLanguage("es", Object.values(import.meta.glob<string>("../language/es.chat.ftl", { query: "?raw", import: "default", eager: true }))[0]);
  expect(replySteps().map(([name]) => name)).toEqual(["Muy corta", "Corta", "Media", "Larga", "Muy larga"]);
});

test("Reply length shows the step nearest its tokens, the five steps of the old Cardwave", () => {
  expect(replySteps().map(([name, tokens]) => `${name} · ${tokens}`)).toEqual(["Very short · 80", "Short · 180", "Medium · 350", "Long · 750", "Very long · 1500"]);
  expect([80, 350, 1500].map(replyStep)).toEqual([0, 2, 4]);
  // A length set otherwise (by the API) shows as the step nearest it.
  expect([1, 120, 300, 600, 100000].map(replyStep)).toEqual([0, 0, 2, 3, 4]);
});

test("Reply length is used where the model does not think and no tool is on, and says why not where it is not", () => {
  expect(replyLengthNote(false, false, false)).toEqual({ used: true, says: "" });
  expect(replyLengthNote(false, true, false)).toEqual({ used: false, says: "Not used while the AI uses tools" });
  expect(replyLengthNote(false, false, true)).toEqual({ used: false, says: "Not used while the AI uses tools" });
  // Thinking wins where both hold.
  expect(replyLengthNote(true, true, true)).toEqual({ used: false, says: "Not used: this model decides its own reply length" });
});

test("a lorebook says in grey that it is the persona's or for every chat, and only one the chat took has its ×", () => {
  const book = (over: Partial<ChatLorebook>): ChatLorebook => ({ lorebook_id: 4, reference: "lorebook.w", name: "World", on: true, entries: [], removed: [], trashed: false, taken: false, everywhere: false, persona: false, ...over });
  expect([bookSays(book({ everywhere: true })), bookSays(book({ persona: true, everywhere: true })), bookSays(book({ taken: true })), bookSays(book({ taken: true, everywhere: true }))]).toEqual([
    { why: "every chat", own: null },
    { why: "persona", own: null },
    { why: null, own: 4 },
    // Taken by the chat as well: the user's own add stays the user's to take off.
    { why: "every chat", own: 4 },
  ]);
});

test("a Reply length the chat did not take, as it was busy, goes back to the step it has", async () => {
  const refused = () => Promise.resolve(false);
  const panel = chatPanel({ setReply: refused, setTalk: refused } as unknown as PanelActions);
  const chat = { reply_length: 350, code_mode: false, talk_pause: 4, talk_replies: 10, trashed: false, prompt_preset: "card" };
  const view = { chat, characters: [], messages: [], lorebooks: [], persona: null, asking: null, modes: [], model: null, thinks: false, tools: false } as unknown as ChatView;
  panel.show({ view, personas: [], library: [], prompts: [], personality: null, locked: false, talking: false, chosen: null });
  const length = panel.node.querySelector<HTMLInputElement>("#chat-reply-length")!;
  const held = length.value;
  length.value = String(replySteps().length - 1);
  length.dispatchEvent(new Event("change"));
  await new Promise((done) => setTimeout(done));
  expect(length.value).toBe(held);
});
