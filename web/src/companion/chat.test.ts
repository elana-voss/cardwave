import { beforeEach, describe, expect, it, vi } from "vitest";

const started: number[] = [];
/** The companion's settings as stored, and the changes saved. */
const companion = { muted: false };
/** The voice's state, as the server tells it. */
const voice = { state: "ready" };
const saved: object[] = [];
vi.mock("../api/client", () => ({
  avatarUrl: () => "",
  cardChats: async () => [],
  getCard: async () => ({ card: { version_id: 7 }, characters: [{ id: "gwen" }] }),
  startChat: async () => {
    started.push(started.length + 1);
    return { chat: { id: started.length } };
  },
  getChat: async (id: number) => ({ chat: { id }, characters: [{ id: 1, name: "Gwen" }], messages: [] }),
  generate: async () => ({}),
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
  read.length = 0;
  saved.length = 0;
  companion.muted = false;
  voice.state = "ready";
});

describe("the compact chat", () => {
  it("starts one chat with a card that has none, also when it is opened twice at once", async () => {
    const { compactChat } = await import("./chat");
    const chat = compactChat(3, { mood: () => {}, replied: () => {}, openFull: () => {}, closed: () => {}, more: () => [] });
    await Promise.all([chat.open(), chat.open()]);
    expect(started).toEqual([1]);
  });

  it("reads the reply it asked for aloud in the card's voice, the figure talking until the reading ends", async () => {
    const { compactChat } = await import("./chat");
    const moods: (string | null)[] = [];
    const chat = compactChat(3, { mood: (mood) => moods.push(mood), replied: () => {}, openFull: () => {}, closed: () => {}, more: () => [] });
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
    const chat = compactChat(3, { mood: () => {}, replied: () => {}, openFull: () => {}, closed: () => {}, more: () => [] });
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
    const chat = compactChat(3, { mood: () => {}, replied: () => {}, openFull: () => {}, closed: () => {}, more });
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
    const chat = compactChat(3, { mood: () => {}, replied: () => {}, openFull: () => {}, closed: () => {}, more: () => [] });
    await chat.open();
    const speaker = chat.node.querySelectorAll<HTMLButtonElement>("header button")[1];
    await vi.waitFor(() => expect(speaker.disabled).toBe(true));
    expect(speaker.title).toMatch(/Voices/);
  });
});
