// A coding step's output as its page shows it, opened in its line: the lines the server keeps as values
// (cw-coding shown.rs `StepLine`, a tool's result `Gave`), worded here in the app's language. The model's own words, a
// file's or page's text and what a command printed stay as they are; Cardwave's own lines around them (a call,
// its exit code, a cut, the plan) are the words of `coding-output-*`. One text, which the page shows in a `pre`.
import type { Gave } from "../api/generated/Gave";
import type { Listed } from "../api/generated/Listed";
import type { StepLine } from "../api/generated/StepLine";
import { failureWords } from "../language/errors";
import { wording } from "../language/language";
import { bytes } from "../format";
import { toolWords } from "./coding";

/** A listing's line: a folder with "/", a file with its size where it is known. */
const listedLine = (entry: Listed) => (entry.folder ? `${entry.name}/` : entry.bytes === null ? entry.name : `${entry.name} (${bytes(entry.bytes)})`);

/** What a tool gave, as the output tells it. */
function gaveText(gave: Gave): string {
  switch (gave.kind) {
    case "refused":
      return wording("coding-output-refused");
    case "failed":
      return wording("coding-failed-with-error", { error: failureWords(gave.error) });
    case "text":
      return gave.whole === null ? gave.text : `${gave.text}\n${wording("coding-output-cut-text", { kept: [...gave.text].length, whole: gave.whole })}`;
    case "listing": {
      if (!gave.entries.length && !gave.more) return wording("coding-output-empty-folder");
      const lines = gave.entries.map(listedLine);
      return [...lines, ...(gave.more ? [wording("coding-output-more", { more: gave.more })] : [])].join("\n");
    }
    case "wrote":
      return wording("coding-output-wrote", { size: bytes(gave.bytes), path: gave.path });
    case "no_results":
      return wording("coding-output-no-results", { query: gave.query });
    case "ran": {
      const ended = gave.code === null ? wording("coding-output-stopped-after", { seconds: gave.seconds }) : wording("coding-output-exit-code", { code: gave.code });
      const drive = gave.drive_refused ? `\n${wording("coding-output-drive-refused")}` : "";
      return `${ended}\n${gave.output}${drive}`;
    }
  }
}

/** A line of the output, with the blank line after it. */
function saidText(said: StepLine): string {
  switch (said.kind) {
    case "words": {
      const cut = said.cut ? wording("coding-output-cut-off") : "";
      return `${[said.text, cut].filter(Boolean).join("\n")}\n\n`;
    }
    case "called":
      return `> ${toolWords(said.tool, said.target)}\n${gaveText(said.gave)}${said.cut ? "\n…" : ""}\n\n`;
    case "plan": {
      const steps = said.steps.map((step, at) => `${at + 1}. ${step}\n`).join("");
      const tests = said.tests ? `${wording("coding-output-tests", { command: said.tests })}\n` : "";
      return `${wording("coding-output-plan")}\n${steps}${tests}`;
    }
  }
}

/** A step's output as one text; empty where it has none. */
export const stepOutput = (output: readonly StepLine[]) => output.map(saidText).join("").trimEnd();
