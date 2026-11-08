// What first run's step 2 shows of its work (the owner's decision of 2026-11-08, Fable's design): `lead`, the one
// sentence under the title (working, slow, ready, one failed, nothing fits); `greyed`, whether the main button
// waits; `workClock`, which makes the work slow after 8 s and gives up what is still open after 30 s, so no
// spinner turns for ever; work the user starts anew counts from its start.
import { wording } from "../language/language";

/** What the step's work has come to. */
export interface StepState {
  /** Whether the picks or a test of the chat or helper model are on their way. */
  open: boolean;
  /** Whether that has taken over 8 s. */
  slow: boolean;
  /** The chat model's ID, "" while none. */
  chat: string;
  chatFailed: boolean;
  workerFailed: boolean;
  /** Whether the list of models or the picks did not come: then nothing was found wanting. */
  noList: boolean;
}

/** After how long open work is slow, and after how long it is given up. */
const SLOW_MS = 8_000;
const LATE_MS = 30_000;

/** The sentence under the step's title. */
export function lead(s: StepState): string {
  if (s.open) return s.slow ? wording("setup-working-slow") : wording("setup-working");
  // Where the main button waits for the chat model, the lead does not say to go on.
  if (s.chatFailed) return wording("setup-chat-failed");
  if (!s.chat) return s.noList ? wording("setup-provider-silent") : wording("setup-none-lead");
  if (s.workerFailed || s.noList) return wording("setup-one-failed");
  return wording("setup-ready");
}

/** Whether the main button waits: for open work, for a chat model, for one that answers. A helper model that did not answer does not hold it: the chat model does its work. */
export const greyed = (s: StepState) => s.open || !s.chat || s.chatFailed;

/** The clock of the step's work: `run` is told whether work is open; `restart` when the user starts work anew ("Change",
 * "Try again"), which then has its own 8 s and 30 s; `changed` when it becomes slow; `late` when it is to be given up. */
export function workClock(changed: () => void, late: () => void): { run(open: boolean): void; restart(): void; slow(): boolean } {
  let timers: ReturnType<typeof setTimeout>[] = [];
  let slow = false;
  const stop = () => {
    timers.forEach(clearTimeout);
    [timers, slow] = [[], false];
  };
  return {
    restart: stop,
    run(open) {
      if (open && !timers.length) {
        timers = [
          setTimeout(() => {
            slow = true;
            changed();
          }, SLOW_MS),
          setTimeout(late, LATE_MS),
        ];
      }
      if (!open) stop();
    },
    slow: () => slow,
  };
}
