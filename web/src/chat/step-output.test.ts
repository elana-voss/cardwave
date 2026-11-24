// What a coding step's output shows: Cardwave's own lines in the app's language, the model's and the tools' text as it is.
import { expect, onTestFinished, test } from "vitest";
import { useLanguage } from "../language/language";
import type { StepLine } from "../api/generated/StepLine";
import { stepOutput } from "./step-output";

const output: StepLine[] = [
  { kind: "plan", steps: ["Schreib den Test"], tests: "npm test" },
  { kind: "words", text: "Ich fange an.", cut: true },
  { kind: "called", tool: "run_command", target: "npm test", gave: { kind: "ran", code: 1, seconds: 3, output: "1 failed", drive_refused: true }, cut: true },
  { kind: "called", tool: "list_files", target: "", gave: { kind: "listing", entries: [{ name: "src", folder: true, bytes: null }], more: 2 }, cut: false },
  { kind: "called", tool: "read_file", target: "a.txt", gave: { kind: "refused" }, cut: false },
];

test("a step's output says Cardwave's own lines in the app's language and the rest as it was", () => {
  onTestFinished(() => useLanguage("en"));
  useLanguage("de", Object.values(import.meta.glob<string>("../language/de{,.*}.ftl", { query: "?raw", import: "default", eager: true })).join("\n"));
  expect(stepOutput(output)).toBe(
    [
      "Der Plan:\n1. Schreib den Test\nTests: npm test",
      "Ich fange an.\n(Die Antwort hat die Längengrenze des Modells erreicht.)\n",
      "> Führt aus: npm test\nExit-Code 1.\n1 failed\n(Die Sandbox lässt keinen Befehl das Laufwerk lesen.)\n…\n",
      "> Sieht sich den Ordner an\nsrc/\n[2 weitere]\n",
      "> Liest a.txt\nDu hast das nicht erlaubt.",
    ].join("\n"),
  );
});

test("a tool's failure is worded by its kind and keeps the outside error's own text", () => {
  const failed = (details: Record<string, string | number>, code: "not_possible" | "not_readable" | "unreachable" = "not_readable"): StepLine => ({
    kind: "called",
    tool: "read_file",
    target: "a.txt",
    gave: { kind: "failed", error: { code, error: "", details } },
    cut: false,
  });
  expect(stepOutput([failed({ what: "file", reason: "Access is denied. (os error 5)" })])).toBe("> Reading a.txt\nFailed: The file cannot be read: Access is denied. (os error 5).");
  expect(stepOutput([failed({ what: "tool_failed", reason: "the disk is full" }, "not_possible")])).toBe("> Reading a.txt\nFailed: the disk is full.");
  expect(stepOutput([failed({ whose: "page", reason: "connection refused" }, "unreachable")])).toBe("> Reading a.txt\nFailed: The page cannot be reached: connection refused.");
});
