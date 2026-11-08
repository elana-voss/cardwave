// The companion window's page (companion.html, board "Companion window"): the figure on the floor of the screen,
// which the hand drags, shakes and throws (body.ts) and a click startles, steered by the worker model (`steer`)
// after each reply in a chat with the companion's card, once it stands again after the hand handled it, and now
// and then while idle (react.ts), else it walks of its own (plan.ts, `wander`); it sleeps after `SLEEP_MS` unused.
// A double-click opens the compact chat (chat.ts), a right-click its menu ("Sit still"), which the chat's More shows
// too; its tooltip says both. The figure is the card's
// and its chat's mode (`companionFigure`), else the base figure of Settings (`companion.figure`), as tall as its size
// there says, a share of the window's height (`companion.size`, `sizeTo`), resized at once. All it is told
// runs through `Companion` (live.ts), which tells the server what the figure does; a bubble shows what it says.
//
// The desktop app shows the page in a see-through, always-on-top window over the work area (desktop/src/main.rs)
// that lets clicks through: the program tells the cursor (`companionCursor`), the page answers whether it is on
// the figure, chat or menu, or the hand holds it (`companion_over`). "Hide until tomorrow" keeps the day in the
// settings and starts the page anew, showing nothing until midnight. The user's own CSS restyles it (own-css.ts);
// its words are in the app's language, read again when the settings change (app-language.ts).
//
// Traps: a click outside the menu goes to another window, so the menu closes on `blur`. The page asks the server
// as the window's account.
import { changeCompanion, companionFigure, companionSaid, connectEvents, figureFileUrl, getSettings, planMoves } from "../api/client";
import type { CompanionFigure } from "../api/generated/CompanionFigure";
import type { Companion as CompanionSettings } from "../api/generated/Companion";
import type { Occasion } from "../api/generated/Occasion";
import type { Figure as CardFigure } from "../api/generated/Figure";
import { contextMenu, type MenuItem } from "../dialogs";
import { desktop, inDesktop, nameWindow } from "../desktop";
import logo from "../logo.png";
import { Body, LONGEST_TICK, SIZE, beside, shaking, sizeTo, stateOf, throwOf, type Mood, type Sample } from "./body";
import { compactChat, type CompactChat } from "./chat";
import { baseSource, Figure, type FigureSource } from "./figure";
import type { BaseFigure } from "../api/generated/BaseFigure";
import { wander } from "./plan";
import { Companion, reporter } from "./live";
import { readWebPictures, webPictures } from "../narration";
import { loudness } from "../voice/voice";
import { readOwnCss, showOwnCss } from "../settings/own-css";
import { readAppLanguage } from "../settings/app-language";
import { Clicks, Reactions } from "./react";
import { followComputer, wording } from "../language/language";
import { el } from "../dom";

/** The least time between two frames, in ms (a little less than a thirtieth of a second, as frames come late). */
const FRAME_MS = 30;
/** Without use for this long the figure sleeps. */
const SLEEP_MS = 5 * 60_000;
/** A click is a click, not half of a double-click, when no second comes within this time (ms). */
const DOUBLE_MS = 300;
/** How long the hand's moves are kept: as long as a shake is looked for in (ms). */
const KEPT_MS = 1000;
/** Standing idle this long, at least and at most, the worker model is asked what the figure does (ms). */
const IDLE_MS = [20_000, 60_000] as const;
/** How far the hand moves before a press is a drag (CSS pixels). */
const SLOP = 5;
/** Room between the figure and its chat. */
const GAP = 12;
/** The least time between two frames while the figure sleeps, in ms. */
const SLEEP_FRAME_MS = 500;

declare global {
  interface Window {
    /** Where the cursor is in the window (CSS pixels), or that it is outside it: the desktop app's cursor poll. */
    companionCursor?: (x: number | null, y: number | null) => void;
  }
}

/** This computer's day as the settings keep it, `days` from today. */
export function dayOf(days = 0, now = new Date()): string {
  const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + days);
  return `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;
}

/** What the page's parts share: the figure, its body and chat, and what it does. */
interface Scene {
  body: Body;
  figure: Figure;
  chat: CompactChat | null;
  /** What it is told to do, and what it knows of itself. */
  live: Companion;
  still: boolean;
  mood: Mood;
  /** When it was last used. */
  used: number;
  /** When the model is asked after a handling or alone. */
  reactions: Reactions;
  /** The hand while it presses on the figure: a press that moves is a drag. */
  hand: { dx: number; dy: number; x: number; y: number; samples: Sample[]; dragging: boolean } | null;
}

async function start(): Promise<void> {
  // The window's name, in the app's language, as in the app's window.
  followComputer();
  nameWindow(() => wording("companion-window"));
  // The program may still hold that the cursor is on what the page showed before it started anew.
  void desktop("companion_over", { over: false }).catch(() => {});
  const settings = await getSettings();
  readAppLanguage(Promise.resolve(settings));
  const companion: CompanionSettings = settings.companion;
  // Whether a picture from another website shows in the compact chat.
  webPictures(settings.web_pictures);
  showOwnCss(settings.own_css);
  if (companion.hidden_until !== null && dayOf() < companion.hidden_until) return untilTomorrow();

  const area = () => ({ width: innerWidth, height: innerHeight });
  let size = companion.size;
  sizeTo(size, innerHeight);
  const body = new Body(area(), Math.max(SIZE.width, innerWidth - 240), innerHeight);
  // The figure of the card and the mode its chat is in; asked again after each reply, as the mode may change.
  let shown = await companionFigure().catch(() => null);
  let base = companion.figure;
  const figure = new Figure(sourceOf(shown, base));
  const follow = () =>
    void companionFigure().then(
      (now) => {
        if (now?.id === shown?.id) return;
        shown = now;
        void figure.change(sourceOf(now, base));
      },
      (error) => console.warn("The companion could not ask which figure to show.", error),
    );
  // The figure sized for the window as it is now, kept inside it.
  const fit = () => {
    sizeTo(size, innerHeight);
    figure.resize();
    body.fit(area());
  };
  // The base figure or its size changed in Settings: shown at once, the figure where the card has none of its own.
  const followBase = () =>
    void getSettings().then(({ companion: now }) => {
      if (now.size !== size) {
        size = now.size;
        fit();
      }
      if (now.figure === base) return;
      base = now.figure;
      if (!shown) void figure.change(sourceOf(null, base));
    }, () => {});
  document.body.append(figure.canvas);
  const steer = steerer(body, () => scene, companion.card_id !== null);
  const ownWalk = () => void (!scene.still && live.act(wander(area())));
  const reactions = new Reactions((occasion) => steer(occasion), ownWalk, () => between(IDLE_MS));
  const live = new Companion(body, figure);
  const scene: Scene = { body, figure, chat: null, live, still: false, mood: null, used: Date.now(), reactions, hand: null };
  const use = () => {
    scene.used = Date.now();
    reactions.used();
  };

  // The compact chat's More shows the figure's menu but "Open chat"; read when pressed, after `lines` is made.
  const { chat, open: openChat } = chatOf(scene, companion.card_id, use, follow, () => lines().slice(1));

  const canvas = figure.canvas;
  const clicks = handle(scene, use);
  canvas.addEventListener("dblclick", () => {
    clicks.down();
    openChat();
  });
  const lines = (): MenuItem[] => [
    { label: wording("main-open-chat"), shape: "chat", action: openChat },
    { label: wording("setup-open"), picture: logo, action: () => openApp(null) },
    { label: scene.still ? wording("main-walk-around") : wording("main-sit-still"), apart: true, action: () => {
        scene.still = !scene.still;
        if (scene.still) body.stop();
      } },
    { label: wording("main-change-character"), shape: "person", action: () => openApp("#/companion") },
    { label: wording("main-hide-until-tomorrow"), apart: true, action: () => void hide() },
    { label: wording("main-quit-companion"), shape: "close", action: quit },
  ];
  contextMenu(canvas, lines);
  // Its tooltip says how it is talked to and where its menu is; set when pointed at, in the language of then.
  canvas.addEventListener("pointerenter", () => (canvas.title = wording("main-figure-hint")));
  window.addEventListener("blur", () => document.dispatchEvent(new PointerEvent("pointerdown")));
  window.addEventListener("resize", fit);
  const report = reporter(companionSaid);
  let heard = false;
  connectEvents((event) => {
    // After a drop the settings may have changed unheard: read as when they change.
    const again = event.type === "hello" && heard;
    if (event.type === "hello") heard = true;
    if (event.type === "companion_act") {
      use();
      live.act(event.steps, event.act);
      return report(() => known(scene), true);
    }
    // A reply in any chat: the server steers by those with the companion's card alone.
    if (event.type === "reply_ended" && !event.error) void steer("reply", event.chat_id)?.then((acted) => acted && use());
    // "Show pictures from other websites" switched in Settings: the messages drawn after follow it.
    if (event.type === "settings" || again) {
      void readWebPictures();
      void readOwnCss();
      readAppLanguage();
      followBase();
    }
    chat?.onEvent(event);
  });

  /** Keeps the day it shows again, and starts the page anew, which shows nothing until then. */
  async function hide(): Promise<void> {
    await changeCompanion({ hidden_until: dayOf(1) });
    location.reload();
  }

  answerCursor(scene);
  animate(scene, area, () => report(() => known(scene)));
}

/** Whether the figure sleeps: unused for `SLEEP_MS`. */
const asleep = (scene: Scene): boolean => Date.now() - scene.used > SLEEP_MS;

/** What the figure is told to do and does, as the server is told it. */
function known(scene: Scene): CompanionFigure {
  const open = !(scene.chat?.node.hidden ?? true);
  return scene.live.state(stateOf(scene.body, scene.mood, asleep(scene), scene.still), open, innerWidth, innerHeight);
}

/**
 * Makes the compact chat with the card `cardId` (none without one) into `scene.chat`, and how it is opened: beside
 * the figure, at its right where there is room, its foot at the figure's feet.
 */
function chatOf(
  scene: Scene,
  cardId: number | null,
  use: () => void,
  follow: () => void,
  more: () => MenuItem[],
): { chat: CompactChat | null; open: () => void } {
  const chat = (scene.chat =
    cardId === null
      ? null
      : compactChat(cardId, {
          mood: (now) => {
            scene.mood = now;
            use();
          },
          replied: () => follow(),
          openFull: (chatId) => openApp(`#/chats/${chatId}`),
          closed: () => void (scene.mood = null),
          more,
        }));
  if (chat) document.body.append(chat.node);
  const open = (): void => {
    if (!chat) return;
    use();
    if (chat.node.hidden) {
      chat.node.hidden = false;
      const { body } = scene;
      const { offsetWidth: width, offsetHeight: height } = chat.node;
      chat.node.style.left = `${Math.max(0, beside(body.x, width, innerWidth))}px`;
      chat.node.style.top = `${Math.max(0, Math.min(body.y - height, innerHeight - height - GAP))}px`;
    }
    void chat.open();
  };
  return { chat, open };
}

/** Asks the worker model what the figure does now, and has it done; whether it gave any moves, or null without a
 * companion. */
function steerer(body: Body, scene: () => Scene, any: boolean): (occasion: Occasion, chatId?: number | null) => Promise<boolean> | null {
  return (occasion, chatId = null) => {
    if (!any) return null;
    const { mood, still, used } = scene();
    const handled = occasion === "handled" ? [...body.happened] : [];
    const alone_s = occasion === "alone" ? Math.round((Date.now() - used) / 1000) : 0;
    const asked = { chat_id: chatId, occasion, handled, alone_s, width: innerWidth, height: innerHeight, x: Math.round(body.x), y: Math.round(body.y), state: stateOf(body, mood, false, still) };
    return planMoves(asked).then(
      ({ steps }) => {
        if (body.motion.kind === "held" || steps.length === 0) return false;
        scene().live.act(steps);
        return true;
      },
      () => false,
    );
  };
}

/** The hand on the figure: a press that moves is a drag, its release a throw; a click that no second click follows
 * startles it, which the double-click cancels (`cancel`). */
function handle(scene: Scene, use: () => void): Clicks {
  const { body, figure } = scene;
  const canvas = figure.canvas;
  let woken = false;
  const clicks = new Clicks(() => body.startle(), DOUBLE_MS);
  canvas.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) return;
    clicks.down();
    woken = asleep(scene);
    use();
    canvas.setPointerCapture(event.pointerId);
    scene.hand = { dx: event.clientX - body.x, dy: event.clientY - body.y, x: event.clientX, y: event.clientY, samples: [], dragging: false };
  });
  canvas.addEventListener("pointermove", (event) => {
    const hand = scene.hand;
    if (!hand) return;
    hand.samples.push({ x: event.clientX, y: event.clientY, at: event.timeStamp });
    while (hand.samples[0]!.at < event.timeStamp - KEPT_MS) hand.samples.shift();
    if (!hand.dragging && Math.hypot(event.clientX - hand.x, event.clientY - hand.y) > SLOP) {
      hand.dragging = true;
      scene.live.stop();
      scene.reactions.took();
      body.hold(woken);
    }
    if (hand.dragging) {
      body.x = Math.min(innerWidth - SIZE.width / 2, Math.max(SIZE.width / 2, event.clientX - hand.dx));
      body.y = Math.min(innerHeight, Math.max(SIZE.height, event.clientY - hand.dy));
    }
  });
  const letGo = (event: PointerEvent) => {
    if (scene.hand?.dragging) {
      const { vx, vy } = throwOf(scene.hand.samples);
      body.release(vx, vy);
    }
    if (scene.hand) clicks.up(scene.hand.dragging || event.type !== "pointerup");
    scene.hand = null;
  };
  canvas.addEventListener("pointerup", letGo);
  canvas.addEventListener("pointercancel", letGo);
  return clicks;
}

/** Answers the desktop app whether the cursor is on what the window shows, told when that changes. */
function answerCursor(scene: Scene): void {
  const { figure } = scene;
  const canvas = figure.canvas;
  let over = false;
  const tell = (now: boolean) => {
    if (now === over) return;
    over = now;
    void desktop("companion_over", { over }).catch(() => {});
  };
  window.companionCursor = (x, y) => {
    if (scene.hand) return tell(true);
    if (x === null || y === null) return tell(false);
    const at = document.elementFromPoint(x, y);
    if (at === canvas) {
      const box = canvas.getBoundingClientRect();
      return tell(figure.opaqueAt(x - box.left, y - box.top));
    }
    tell(at !== null && at !== document.body && at !== document.documentElement);
  };
}

/** Each frame: what it was told, else the model asked once the figure stands after a handling or now and then while
 * it stands idle (`Reactions`); the body; the figure where its feet are, and its bubble over it; then `report`. */
function animate(scene: Scene, area: () => { width: number; height: number }, report: () => void): void {
  const { body, figure, chat, live } = scene;
  const canvas = figure.canvas;
  const bubble = el("div", { className: "bubble companion-say", hidden: true });
  document.body.append(bubble);
  let last = performance.now();
  const frame = (now: number) => {
    // At most 30 frames a second, as more costs the processor for nothing (the spike: 45% of a core at 165 Hz),
    // and two while it sleeps.
    const sleeping = asleep(scene);
    if (now - last < (sleeping && body.motion.kind === "rest" ? SLEEP_FRAME_MS : FRAME_MS)) return void requestAnimationFrame(frame);
    const dt = Math.min((now - last) / 1000, LONGEST_TICK);
    last = now;
    if (scene.hand?.dragging) body.shake(shaking(scene.hand.samples, now));
    const resting = !scene.hand && body.motion.kind === "rest" && !body.gettingUp;
    if (resting) scene.reactions.standing(!live.busy && !sleeping && (chat?.node.hidden ?? true), Date.now());
    live.step(dt, scene.still);
    body.rising = figure.rising;
    body.step(dt);
    canvas.style.transform = `translate(${body.x - SIZE.width / 2}px, ${body.y - SIZE.height}px)`;
    bubble.hidden = live.said === null;
    if (live.said !== null) {
      bubble.textContent = live.said;
      bubble.style.left = `${body.x}px`;
      bubble.style.top = `${body.y - SIZE.height}px`;
    }
    const state = stateOf(body, scene.mood, sleeping, scene.still);
    const box = chat && !chat.node.hidden ? chat.node.getBoundingClientRect() : null;
    figure.show(state, body.heading, box ? Math.sign(box.left + box.width / 2 - body.x) : 0);
    figure.draw(dt, loudness());
    report();
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}

/** Where the card's figure's file is, else the base figure's, or none for the robot. */
const sourceOf = (figure: CardFigure | null, base: BaseFigure): FigureSource | null =>
  figure ? { url: figureFileUrl(figure.id), kind: figure.kind as FigureSource["kind"] } : baseSource(base);

/** A time between the two, in ms. */
const between = ([least, most]: readonly [number, number]) => least + Math.random() * (most - least);

/** Shows Cardwave's window at `hash`; in a browser, a tab. */
function openApp(hash: string | null): void {
  if (inDesktop()) void desktop("open_main", { hash }).catch(() => {});
  else window.open(`/${hash ?? ""}`, "_blank");
}

function quit(): void {
  if (inDesktop()) void desktop("companion_quit").catch(() => {});
  else window.close();
}

/** Nothing shows until tomorrow, when the page starts anew; the cursor is never on it meanwhile. */
function untilTomorrow(): void {
  const midnight = new Date();
  midnight.setHours(24, 0, 1, 0);
  setTimeout(() => location.reload(), midnight.getTime() - Date.now());
}

void start();
