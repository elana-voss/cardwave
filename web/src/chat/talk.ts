// The characters of a chat of several replying by themselves, one reply after another, which the line "Keep
// replying by themselves" of "Who replies" starts and the notice's Stop, the user's message or the limit ends.
// The pause between replies and the limit are the chat's (`talk_pause`, `talk_replies`), read as each next reply is
// waited for, so a change in the side panel counts from the pause after the one under way.
//
// Traps: it is the page's doing, not the server's, so it ends when the chat is left; `onward` is called at every
// drawing and asks for the next reply only once nothing is being written.
import type { ChatView } from "../api/generated/ChatView";
import { announce } from "../dom";
import { act, busy, reply, stop, type Screen } from "./screen";
import { wording } from "../language/language";

/**
 * Whether the characters of a chat can keep replying by themselves: they go by
 * the chat's turn order, so not while one is picked by hand, and they answer
 * each other, so two at least must be able to reply.
 */
export const canTalk = ({ chat, characters }: ChatView): boolean => chat.replier_id === null && characters.length > 1;

/** Has the characters keep replying by themselves, from the next reply on. */
export function talkOn(s: Screen): void {
  if (s.talk || !s.view || !canTalk(s.view)) return;
  s.talk = { asked: 0, asking: false, timer: 0, stopped: false };
  s.render();
}

/**
 * Ends the characters' replying by themselves; with `stopping`, as the user
 * stopped it, the reply being written, or about to be, is stopped too.
 */
export function halt(s: Screen, stopping = false): void {
  if (!end(s, stopping)) return;
  if (stopping && busy(s)) void stop(s);
  s.render();
}

/** Ends the characters' replying by themselves without drawing the chat anew; answers whether they were. */
export function end(s: Screen, stopping = false): boolean {
  if (!s.talk) return false;
  clearTimeout(s.talk.timer);
  s.talk.stopped = stopping;
  s.talk = null;
  return true;
}

/**
 * Has the characters' next reply asked for once nothing is being written:
 * the first at once, the others after the pause, none past the limit. Called
 * whenever the chat is drawn.
 */
export function onward(s: Screen): void {
  const talk = s.talk;
  if (!talk || !s.view || talk.asking || talk.timer || busy(s)) return;
  // Replies in a row at most, as each costs at a paid provider; then they stop.
  const { talk_pause, talk_replies } = s.view.chat;
  if (talk.asked < talk_replies) {
    talk.timer = window.setTimeout(() => void ask(s), talk.asked ? talk_pause * 1000 : 0);
    return;
  }
  halt(s);
  announce(wording("talk-the-characters-stopped-after", { asked: talk.asked }), async () => talkOn(s), false, wording("talk-go-on"));
}

/** Asks for the characters' next reply, by whom the chat's turn says; one that cannot be had ends their replying. */
async function ask(s: Screen): Promise<void> {
  const mine = s.talk;
  if (!mine) return;
  mine.timer = 0;
  // Another action is on its way: the reply waits for it.
  if (s.working) {
    mine.timer = window.setTimeout(() => void ask(s), 100);
    return;
  }
  mine.asking = true;
  mine.asked += 1;
  s.render();
  const done = await act(s, () => reply(s));
  mine.asking = false;
  if (s.talk !== mine) {
    // Stopped while the reply was asked for: it is stopped as it begins.
    if (mine.stopped && busy(s)) void stop(s);
    return;
  }
  if (!done) return halt(s);
  onward(s);
}
