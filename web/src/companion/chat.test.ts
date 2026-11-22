import { beforeEach, describe, expect, it, vi } from "vitest";

const started: number[] = [];
/** The companion's settings as stored, and the changes saved. */
const companion = { muted: false };
/** The voice's state, as the server tells it. */
const voice = { state: "ready" };
const saved: object[] = [];
/** The card's chats, newest first, as the server lists them. */
const chats: { id: number }[] = [];
const failing = { chats: false };
/** What the answer to `generate` waits for, where a test holds it back. */
const held: { generate?: Promise<void> } = {};
/** The chats shown. */
const viewed: number[] = [];
vi.mock("../api/client", () => ({
  avatarUrl: () => "",
  cardChats: async () => {
    if (failing.chats) throw new Error("not answering");
    return chats;
  },
  getCard: async () => ({ card: { version_id: 7 }, characters: [{ id: "gwen" }] }),
  startChat: async () => {
    started.push(started.length + 1);
    return { chat: { id: started.length } };
  },
  getChat: async (id: number) => (viewed.push(id), { chat: { id }, characters: [{ id: 1, name: "Gwen" }, ...(id === 9 ? [{ id: 2, name: "Bram" }] : [])], messages: [] }),
  generate: async () => {
    await held.generate;
    return { id: 5, content: "" };
  },
  sendMessage: async () => ({ id: 4 }),
  getVoice: async () => ({ state: voice.state, rate: 24_000, at_provider: false }),
  getSettings: async () => ({ companion: { ...companion } }),
  changeCompanion: async (patch: object) => {
    saved.push(patch);
    Object.assign(companion, patch);
    return { companion: { ...companion } };
  },
}));
/** What was read aloud, and how to end each reading. */
const read: { text: string; card?: number; ended: () => void }[] = [];
vi.mock("../voice/voice", () => ({
  spoken: (text: string) => text.replaceAll("*", ""),
  stopReading: () => {},
  readAloud: (text: string, _rate: number, ended: () => void, reader: { card?: number }) => {
    read.push({ text, card: reader.card, ended });
    return () => {};
  },
}));

beforeEach(() => {
  started.length = 0;
  chats.length = 0;
  viewed.length = 0;
  read.length = 0;
  saved.length = 0;
  companion.muted = false;
  voice.state = "ready";
  failing.chats = false;
  held.generate = undefined;
});

describe("the compact chat", () => {
  const hooks = { mood: () => {}, replied: () => {}, openFull: () => {}, talks: () => {}, closed: () => {}, more: () => [] };

  /** The letters told to the figure's lips as a reply it asked for comes in and ends, in pieces "Hi" and "Hi there". */
  async function lettersOf(): Promise<(string | null)[]> {
    const { compactChat } = await import("./chat");
    const talked: (string | null)[] = [];
    const moods: (string | null)[] = [];
    const chat = compactChat(3, { ...hooks, mood: (mood) => moods.push(mood), talks: (letters) => talked.push(letters) });
    await chat.open();
    const input = chat.node.querySelector("textarea")!;
    input.value = "Hello";
    input.form!.requestSubmit();
    await vi.waitFor(() => expect(moods).toContain("thinking"));
    await new Promise((done) => setTimeout(done, 0));
    chat.onEvent({ type: "reply_text", chat_id: 1, message_id: 5, start: 0, text: "Hi" } as never);
    chat.onEvent({ type: "reply_text", chat_id: 1, message_id: 5, start: 2, text: " there" } as never);
    chat.onEvent({ type: "reply_ended", chat_id: 1, message: { id: 5, content: "Hi there" } } as never);
    return talked;
  }

  it("tells the figure's lips a reply's letters as they come while no voice will read it, and its end", async () => {
    voice.state = "absent";
    expect(await lettersOf()).toEqual(["Hi", " there", null]);
  });

  it("tells the lips no letters of a reply its voice will read, as the voice moves them", async () => {
    expect(await lettersOf()).toEqual([null]);
  });

  it("tells the lips the letters of a reply while its voice is muted", async () => {
    companion.muted = true;
    expect(await lettersOf()).toEqual(["Hi", " there", null]);
  });

  it("shows a reply's words that came before the answer that started it, and tells them to the lips", async () => {
    voice.state = "absent";
    let answer = () => {};
    held.generate = new Promise((done) => (answer = done));
    const { compactChat } = await import("./chat");
    const talked: (string | null)[] = [];
    const chat = compactChat(3, { ...hooks, talks: (letters) => talked.push(letters) });
    await chat.open();
    const input = chat.node.querySelector("textarea")!;
    input.value = "Hello";
    input.form!.requestSubmit();
    await vi.waitFor(() => expect(chat.node.querySelectorAll(".bubble").length).toBe(1));
    chat.onEvent({ type: "reply_text", chat_id: 1, message_id: 5, start: 0, text: "Hi" } as never);
    answer();
    await vi.waitFor(() => expect(chat.node.querySelectorAll(".bubble").length).toBe(2));
    chat.onEvent({ type: "reply_text", chat_id: 1, message_id: 5, start: 2, text: " there" } as never);
    expect(chat.node.querySelectorAll(".bubble")[1].textContent).toBe("Hi there");
    expect(talked).toEqual(["Hi", " there"]);
  });

  it("starts one chat with a card that has none, also when it is opened twice at once", async () => {
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, hooks);
    await Promise.all([chat.open(), chat.open()]);
    expect(started).toEqual([1]);
  });

  it("opens the card's own chat, never a chat of several the card is in", async () => {
    chats.push({ id: 9 }, { id: 8 });
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, hooks);
    await chat.open();
    expect(started).toEqual([]);
    expect(viewed.at(-1)).toBe(8);
    // Only in a chat of several: a chat of its own is started.
    chats.splice(1);
    const other = compactChat(3, hooks);
    await other.open();
    expect(started).toEqual([1]);
  });

  it("reads the reply it asked for aloud in the card's voice, the figure talking until the reading ends", async () => {
    const { compactChat } = await import("./chat");
    const moods: (string | null)[] = [];
    const chat = compactChat(3, { ...hooks, mood: (mood) => moods.push(mood) });
    await chat.open();
    const input = chat.node.querySelector("textarea")!;
    input.value = "Hello";
    input.form!.requestSubmit();
    await vi.waitFor(() => expect(moods).toContain("thinking"));
    chat.onEvent({ type: "reply_ended", chat_id: 1, message: { id: 5, content: "*Smiles.* Hi." } } as never);
    await vi.waitFor(() => expect(read).toEqual([{ text: "Smiles. Hi.", card: 3, ended: expect.any(Function) }]));
    expect(moods.at(-1)).toBe("talking");
    read[0].ended();
    expect(moods.at(-1)).toBe(null);
    // A reply this box did not ask for (another window's) is not read.
    chat.onEvent({ type: "reply_ended", chat_id: 1, message: { id: 6, content: "Bye." } } as never);
    expect(read).toHaveLength(1);
  });

  it("reads no reply while the speaker in its head is off, which is kept with the settings", async () => {
    companion.muted = true;
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, hooks);
    await chat.open();
    // The head's buttons: "Open in Cardwave", the speaker, More, Close.
    const speaker = chat.node.querySelectorAll<HTMLButtonElement>("header button")[1];
    await vi.waitFor(() => expect(speaker.ariaPressed).toBe("false"));
    const ask = async (id: number) => {
      const input = chat.node.querySelector("textarea")!;
      input.value = "Hello";
      input.form!.requestSubmit();
      await new Promise((done) => setTimeout(done));
      chat.onEvent({ type: "reply_ended", chat_id: 1, message: { id, content: "Hi." } } as never);
    };
    await ask(5);
    expect(read).toHaveLength(0);
    speaker.click();
    await vi.waitFor(() => expect(saved).toEqual([{ muted: false }]));
    expect(speaker.ariaPressed).toBe("true");
    await ask(7);
    expect(read).toHaveLength(1);
  });

  it("has a More in its head that opens the figure's menu, read anew at each press", async () => {
    const { compactChat } = await import("./chat");
    let still = false;
    const more = () => [{ label: still ? "Walk around" : "Sit still", action: () => void (still = !still) }];
    const chat = compactChat(3, { ...hooks, more });
    document.body.append(chat.node);
    await chat.open();
    const button = chat.node.querySelectorAll<HTMLButtonElement>("header button")[2];
    button.click();
    const line = () => [...document.querySelectorAll<HTMLButtonElement>(".pop button")];
    expect(line().map((one) => one.textContent)).toEqual(["Sit still"]);
    line()[0].click();
    expect(still).toBe(true);
    expect(line()).toHaveLength(0);
    button.click();
    expect(line().map((one) => one.textContent)).toEqual(["Walk around"]);
    chat.node.remove();
  });

  it("greys its speaker, saying why, while no voice is set up", async () => {
    voice.state = "absent";
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, hooks);
    await chat.open();
    const speaker = chat.node.querySelectorAll<HTMLButtonElement>("header button")[1];
    await vi.waitFor(() => expect(speaker.disabled).toBe(true));
    expect(speaker.title).toMatch(/Voices/);
  });

  it("asks the server again for its chat after a failed search", async () => {
    chats.push({ id: 8 });
    failing.chats = true;
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, hooks);
    await chat.open();
    expect(viewed).toEqual([]);
    failing.chats = false;
    await chat.open();
    // Once to find the chat, once to show it.
    expect(viewed).toEqual([8, 8]);
  });

  it("finds the chat anew when the one it had was deleted or archived", async () => {
    chats.push({ id: 8 });
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, hooks);
    await chat.open();
    chats.splice(0, 1, { id: 7 });
    chat.onEvent({ type: "trash" } as never);
    await vi.waitFor(() => expect(viewed.at(-1)).toBe(7));
  });

  it("can send again after the server is heard anew, a reply's end having been missed", async () => {
    chats.push({ id: 8 });
    const { compactChat } = await import("./chat");
    const moods: (string | null)[] = [];
    const chat = compactChat(3, { ...hooks, mood: (mood) => moods.push(mood) });
    await chat.open();
    // The reply began and its end was never heard.
    chat.onEvent({ type: "hello" } as never);
    chat.onEvent({ type: "reply_text", chat_id: 8, message_id: 4, start: 0, text: "Hi" } as never);
    chat.onEvent({ type: "hello" } as never);
    const input = chat.node.querySelector("textarea")!;
    input.value = "Two";
    input.form!.requestSubmit();
    await vi.waitFor(() => expect(moods).toContain("thinking"));
  });
});
