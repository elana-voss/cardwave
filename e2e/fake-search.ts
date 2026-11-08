// The stand-in for the search model, as server/tests/common/embedder.rs is for the server's tests: it serves
// `searchModel` of server.mjs as the model's download (dictation's too) and answers as llama-server does. A text's tokens are its
// words; its vector counts its words of each of a few topics (the sea, space, the forest), and every other word
// a twentieth in a dimension of its letters, so "ocean" is near a text about a lighthouse that never says it.
// It listens on the port 300 above its worker's server's, which the server is told (server.mjs). `hold` keeps
// the next download at its third piece until `release`.
import { createServer } from "node:http";
import { ports, searchModel } from "./server.mjs";

const TOPICS = [
  ["sea", "ocean", "lighthouse", "storm", "ship", "harbor", "waves", "tide", "keeper"],
  ["space", "star", "stars", "starship", "planet", "orbit", "galaxy", "pilot"],
  ["forest", "tree", "trees", "woods", "elf", "moss", "deer"],
];
const OTHERS = 1024;
const PIECE = 16 * 1024;

const PORT = ports(Number(process.env.TEST_PARALLEL_INDEX ?? 0)).search;

function vector(text: string): number[] {
  const vector = new Array<number>(TOPICS.length + OTHERS).fill(0);
  for (const word of text.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean)) {
    const topic = TOPICS.findIndex((words) => words.includes(word));
    if (topic >= 0) vector[topic] += 1;
    else vector[TOPICS.length + ([...word].reduce((hash, c) => (hash * 31 + c.codePointAt(0)!) >>> 0, 7) % OTHERS)] += 0.05;
  }
  return vector;
}

export interface FakeSearch {
  hold(): void;
  release(): void;
  close(): Promise<void>;
}

export async function startFakeSearch(): Promise<FakeSearch> {
  const model = searchModel();
  let held: Promise<void> | null = null;
  let release = () => {};
  const server = createServer(async (req, res) => {
    if (req.url === "/model.gguf") {
      res.writeHead(200, { "Content-Type": "application/octet-stream", "Content-Length": model.length });
      for (let at = 0; at < model.length; at += PIECE) {
        if (at === 2 * PIECE && held) await held;
        res.write(model.subarray(at, at + PIECE));
      }
      res.end();
      return;
    }
    let body = "";
    for await (const part of req) body += part;
    const asked = body ? JSON.parse(body) : {};
    const answer =
      req.url === "/tokenize"
        ? { tokens: String(asked.content).split(/\s+/).filter(Boolean) }
        : req.url === "/v1/embeddings"
          ? { data: (asked.input as string[]).map((text, index) => ({ index, embedding: vector(text) })) }
          : { status: "ok" };
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(answer));
  });
  await new Promise<void>((listening) => server.listen(PORT, "127.0.0.1", listening));
  return {
    hold: () => void (held = new Promise((go) => (release = () => ((held = null), go())))),
    release: () => release(),
    close: () =>
      new Promise((closed) => {
        release();
        server.closeAllConnections();
        server.close(() => closed());
      }),
  };
}
