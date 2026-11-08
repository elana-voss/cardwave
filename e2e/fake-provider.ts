// A stand-in for the user's model server (OpenAI's chat-completions API, and the list of its models), run inside
// the test, so a spec decides what it answers; the specs never talk to a live provider. Beside it a stand-in for
// the hosts the server asks when it looks for a provider's API.
//
// `startFakeProvider`: `models` says what its list of models is and `listed` notes the askings; a reply repeats
// the user's last message, unless a test says what it is (`next`) or that it calls a tool (`calls`). The
// memory's helper (`HELPER`, crates/cw-chat/src/memory/hybrid.rs) is answered apart, without taking a scripted reply or
// being noted in `asked`, with the reply `remembers` gives, else one that finds nothing; the picker of a chat's
// mode (`PICKER`) with the mode `picks` names, else none; the companion's animator (`ANIMATOR`) with the moves
// `moves` names, else none, noted in `animated`. A picture asked for (`/images/generations`) is
// answered with `PICTURE`, or the file `paints` gave, and noted in `pictured`.
// `startFakePlaces` listens on the port 100 above its worker's server's (`CARDWAVE_PROVIDER_PLACES` in
// server.mjs, read by a debug build only) and answers 404 as JSON but for the places a test names (`answer`);
// the websites are made up and end in `.test`. models.dev's list is asked there too (`/models.dev/api.json`), so
// without `answer` first run picks by the list shipped with the server.
import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import { ports } from "./server.mjs";

interface Scripted {
  pieces: string[];
  /** A tool the reply calls, with its arguments, in place of the pieces. */
  call?: { name: string; arguments: unknown };
  /** Answer with this HTTP status and the pieces as the error's message. */
  status?: number;
  /** Resolves when the next piece after the first may be sent. */
  step?: () => Promise<void>;
  /** Called when the server hangs up before the reply is through. */
  hungUp?: () => void;
}

/** A reply that waits after its first piece. */
export interface Held {
  /** Sends one more piece. */
  next(): void;
  /** Sends the rest of the reply. */
  release(): void;
  /** Whether the server hung up before the reply was through. */
  hungUp(): boolean;
}

export interface FakeProvider {
  /** What to set as the provider's address. */
  url: string;
  /** The requests for a reply received, oldest first. */
  asked: { key: string | undefined; body: any }[];
  /** What the pictures were asked for with, oldest first. */
  pictured: { model: string; prompt: string }[];
  /** From now on every picture asked for is this file. */
  paints(file: Buffer): void;
  /** The askings for the list of models, oldest first: the path asked, and the key that came with it. */
  listed: { path: string; key: string | undefined }[];
  /** From now on the list of models is these IDs, or an answer with this status and body (a text is sent as it is). Without it the server has no list (404). */
  models(list: string[] | { status: number; body: unknown; type?: string }): void;
  /** The next reply, in these pieces. Without one, a reply echoes the user's last message. */
  next(pieces: string[]): void;
  /** The next reply stops after its first piece until it is let on. */
  hold(pieces: string[]): Held;
  /** The next reply calls the tool `name` with `args`. */
  calls(name: string, args: unknown): void;
  /** The next request fails with this status and reason. */
  fail(status: number, reason: string): void;
  /** What the memory's helper answers every block with from now on: a PRESENT line, then FACTS and EVENTS rows. */
  remembers(reply: string): void;
  /** The mode the picker of a chat's mode answers with from now on. */
  picks(mode: string): void;
  /** What the companion's animator was asked, oldest first. */
  animated: { body: any }[];
  /** The moves the companion's animator answers with from now on (crates/cw-chat/src/companion.rs). */
  moves(steps: unknown[]): void;
  close(): Promise<void>;
}

/**
 * A stand-in for every host the server asks when it looks for a provider's API on a website. The server of the
 * spec file asks it in place of them (`CARDWAVE_PROVIDER_PLACES` in server.mjs), `https://host/path` as `/host/path`.
 */
export interface FakePlaces {
  /** What was asked, oldest first: the host with the path, and the key that came with it, if any. */
  asked: { method: string; place: string; key: string | undefined }[];
  /** From now on a place that starts with `at` (`api.example.test/v1/models`) answers so. Without a rule a place answers 404 as JSON. */
  answer(at: string, status: number, body: unknown, type?: string): void;
  close(): Promise<void>;
}

/** The port this worker's server looks for a provider's API on. Playwright tells a worker its number. */
const PLACES_PORT = ports(Number(process.env.TEST_PARALLEL_INDEX ?? 0)).places;

export async function startFakePlaces(): Promise<FakePlaces> {
  const asked: FakePlaces["asked"] = [];
  const rules: { at: string; status: number; body: unknown; type: string }[] = [];
  const server = createServer((req, res) => {
    const place = (req.url ?? "").slice(1);
    asked.push({ method: req.method ?? "", place, key: req.headers.authorization });
    const rule = rules.find(({ at }) => place.startsWith(at)) ?? { status: 404, body: { detail: "Not Found" }, type: "application/json" };
    res.writeHead(rule.status, { "Content-Type": rule.type });
    res.end(typeof rule.body === "string" ? rule.body : JSON.stringify(rule.body));
  });
  await new Promise<void>((listening) => server.listen(PLACES_PORT, "127.0.0.1", listening));
  return {
    asked,
    answer: (at, status, body, type = "application/json") => void rules.unshift({ at, status, body, type }),
    close: () =>
      new Promise((closed) => {
        server.closeAllConnections();
        server.close(() => closed());
      }),
  };
}

/** How the memory helper's prompt begins. */
const HELPER = "Read these new messages of a ";
/** A helper's reply that finds nothing. */
export const NOTHING = "PRESENT:\nFACTS:\nEVENTS:";
const PICKER = "You pick the mode of a chat.";
const ANIMATOR = "You move a character's figure";

/** A picture of one pixel, as a PNG in base64: what every picture asked for is. */
export const PICTURE = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

const event = (text: string) => `data: ${JSON.stringify({ choices: [{ delta: { content: text } }] })}\n\n`;

export async function startFakeProvider(): Promise<FakeProvider> {
  const asked: FakeProvider["asked"] = [];
  const listed: FakeProvider["listed"] = [];
  const pictured: FakeProvider["pictured"] = [];
  let painted = PICTURE;
  let list: { status: number; body: unknown; type?: string } = { status: 404, body: { detail: "Not Found" } };
  const script: Scripted[] = [];
  let remembered = NOTHING;
  let picked = "";
  const animated: FakeProvider["animated"] = [];
  let steps: unknown[] = [];

  const server = createServer(async (req, res) => {
    if (req.method === "GET") {
      listed.push({ path: req.url ?? "", key: req.headers.authorization });
      res.writeHead(list.status, { "Content-Type": list.type ?? "application/json" });
      res.end(typeof list.body === "string" ? list.body : JSON.stringify(list.body));
      return;
    }
    let raw = "";
    for await (const part of req) raw += part;
    const body = JSON.parse(raw);
    if (req.url?.endsWith("/images/generations")) {
      pictured.push(body);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ data: [{ b64_json: painted }] }));
      return;
    }
    if (String(body.messages[0]?.content ?? "").startsWith(PICKER)) {
      res.writeHead(200, { "Content-Type": "text/event-stream" });
      res.end(`${event(JSON.stringify({ mode: picked }))}data: [DONE]\n\n`);
      return;
    }
    if (String(body.messages[0]?.content ?? "").startsWith(ANIMATOR)) {
      animated.push({ body });
      res.writeHead(200, { "Content-Type": "text/event-stream" });
      res.end(`${event(JSON.stringify({ steps }))}data: [DONE]\n\n`);
      return;
    }
    if (String(body.messages[0]?.content ?? "").startsWith(HELPER)) {
      res.writeHead(200, { "Content-Type": "text/event-stream" });
      res.end(`${event(remembered)}data: [DONE]\n\n`);
      return;
    }
    asked.push({ key: req.headers.authorization, body });
    const said = body.messages.findLast((message: { role: string }) => message.role === "user");
    const reply = script.shift() ?? { pieces: [`Echo: ${said?.content}`] };
    if (reply.status) {
      res.writeHead(reply.status, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: { message: reply.pieces.join("") } }));
      return;
    }
    res.on("close", () => {
      if (!res.writableEnded) reply.hungUp?.();
    });
    res.writeHead(200, { "Content-Type": "text/event-stream" });
    if (reply.call) {
      const call = { index: 0, id: "call_1", type: "function", function: { name: reply.call.name, arguments: JSON.stringify(reply.call.arguments) } };
      res.end(`data: ${JSON.stringify({ choices: [{ delta: { tool_calls: [call] } }] })}\n\ndata: [DONE]\n\n`);
      return;
    }
    const [first, ...rest] = reply.pieces;
    res.write(event(first));
    for (const text of rest) {
      await reply.step?.();
      res.write(event(text));
    }
    res.end("data: [DONE]\n\n");
  });
  await new Promise<void>((listening) => server.listen(0, "127.0.0.1", listening));

  return {
    url: `http://127.0.0.1:${(server.address() as AddressInfo).port}/v1`,
    asked,
    listed,
    pictured,
    paints: (file) => void (painted = file.toString("base64")),
    models: (answer) => void (list = Array.isArray(answer) ? { status: 200, body: { object: "list", data: answer.map((id) => ({ id, object: "model" })) } } : answer),
    next: (pieces) => void script.push({ pieces }),
    calls: (name, args) => void script.push({ pieces: [], call: { name, arguments: args } }),
    hold(pieces) {
      // How many more pieces may go out, and the piece that waits for it.
      let allowed = 0;
      let waiting: (() => void) | undefined;
      let hungUp = false;
      const step = () =>
        new Promise<void>((go) => {
          if (allowed > 0) {
            allowed--;
            go();
          } else waiting = go;
        });
      const next = () => {
        const go = waiting;
        waiting = undefined;
        if (go) go();
        else allowed++;
      };
      const release = () => {
        allowed = Infinity;
        next();
      };
      script.push({ pieces, step, hungUp: () => (hungUp = true) });
      return { next, release, hungUp: () => hungUp };
    },
    fail: (status, reason) => void script.push({ pieces: [reason], status }),
    remembers: (reply) => void (remembered = reply),
    picks: (mode) => void (picked = mode),
    animated,
    moves: (answer) => void (steps = answer),
    close: () =>
      new Promise((closed) => {
        server.closeAllConnections();
        server.close(() => closed());
      }),
  };
}
