// The password over the app's key (crates/cw-accounts/src/password.rs).
//
// `passwordLine` is the line that says whether one is on, with "Switch on", or "Change" and "Switch off", which
// the profile has as "Password", its one place (the owner, 2026-10-15). Its dialog is
// `passwordDialog`, a form dialog whose fields `asked` turns into what the server is asked; the red box says what
// a forgotten password means. Of another account than this computer's (`other`) the line is that account's own
// password, which signs it in, and has "Change" alone. `startScreen` is what main.ts shows in the app's place
// while the server waits for the password, and accounts.ts where a page signs in: the logo, "Back" where one was
// picked of several, the account's letter and name, the field and "Open" (or "Sign in"), which gives the password
// to `take`, and under it what a forgotten password means; a wrong one is said under the field, and the wait after
// too many counts down there and clears itself. `passwordIs`
// says whether this computer's account has one on (main.ts at the start, the dialog at a change), and
// `watchPassword` passes it on to the account's menu, whose "Lock" goes by it.
import { wording } from "../language/language";
import { ApiError, setPassword } from "../api/client";
import type { ChangePassword } from "../api/generated/ChangePassword";
import { announce, el, noticeBox, oneAtATime } from "../dom";
import { formDialog } from "../dialogs";
import { initialOf } from "../format";
import logo from "../logo.png";

/** Whether this computer's account has a password on, and who is told when that changes. */
let passwordOn = false;
const passwordWatchers: ((on: boolean) => void)[] = [];

/** Tells everyone watching whether a password is on now. */
export function passwordIs(on: boolean): void {
  passwordOn = on;
  for (const watcher of passwordWatchers) watcher(on);
}

/** Tells `watcher` whether a password is on, now and at every change. */
export function watchPassword(watcher: (on: boolean) => void): void {
  passwordWatchers.push(watcher);
  watcher(passwordOn);
}

/** What the dialog does: switch a password on, change it, or switch it off. */
export type Kind = "on" | "change" | "off";

/** What the dialog of each kind says: its title, its words, its button and what it says when done. */
function kinds(): Record<Kind, { title: string; says: string; action: string; done: string }> {
  return {
    on: { title: wording("password-on-title"), says: wording("password-on-says"), action: wording("password-on"), done: wording("password-on-done") },
    change: { title: wording("password-change-title"), says: wording("password-change-says"), action: wording("password-change"), done: wording("password-change-done") },
    off: { title: wording("password-off-title"), says: wording("password-off-says"), action: wording("password-off"), done: wording("password-off-done") },
  };
}

/** What the dialog of `kind` asks the server for, of what was typed into its fields. Two passwords that differ are asked for nowhere. */
export function asked(kind: Kind, typed: { current?: string; password?: string; repeat?: string }): ChangePassword {
  if (kind !== "off" && typed.password !== typed.repeat) throw new Error(wording("password-differ"));
  if (kind === "on") return { password: typed.password };
  if (kind === "change") return { current: typed.current, password: typed.password };
  return { current: typed.current };
}

/** A password's field under its name. */
export function field(id: string, name: string, autocomplete: "current-password" | "new-password"): { input: HTMLInputElement; node: HTMLElement } {
  const input = el("input", { id, className: "field", type: "password", required: true, autocomplete });
  return { input, node: el("div", { className: "fld" }, el("label", { htmlFor: id }, name), input) };
}


/** Opens the dialog of `kind` in `home`, of another account's password where `other`; `done` is told whether a password is on once it is done. */
export function passwordDialog(home: HTMLElement, kind: Kind, done: (on: boolean) => void, other = false): HTMLDialogElement {
  const { title, action, done: said, says: own } = kinds()[kind];
  const says = other ? wording("password-other-says") : own;
  const current = kind === "on" ? null : field("password-current", wording("password-current"), "current-password");
  const password = kind === "off" ? null : field("password-new", kind === "on" ? wording("password-password") : wording("password-new"), "new-password");
  const repeat = kind === "off" ? null : field("password-repeat", wording("password-repeat"), "new-password");
  const fields = [
    el("p", { className: "dialog-says hint c-ink" }, says),
    current?.node,
    password?.node,
    repeat?.node,
    kind === "off" ? null : el("p", { className: "banner warning" }, other ? wording("password-other-forgotten") : wording("password-forgotten")),
  ];
  const box = formDialog(
    home,
    title,
    fields,
    async () => {
      const typed = { current: current?.input.value, password: password?.input.value, repeat: repeat?.input.value };
      const { password: on } = await setPassword(asked(kind, typed));
      if (!other) passwordIs(on);
      box.close();
      done(on);
      announce(said);
    },
    action,
  );
  (current ?? password)!.input.focus();
  return box;
}

/**
 * The line of the password, called `label`: whether one is on, and what changes that. `home` is the screen its
 * dialog stands in, `changed` is told whether one is on after the dialog. Its buttons show once `show` has told it.
 */
export function passwordLine(label: string, home: () => HTMLElement, changed: (on: boolean) => void = () => {}): { node: HTMLElement; show(on: boolean, other?: boolean): void } {
  const says = el("span", { className: "meta" });
  let other = false;
  const open = (kind: Kind) => () => passwordDialog(home(), kind, (on) => (show(on, other), changed(on)), other);
  const switchOn = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("password-on-title"), hidden: true, onclick: open("on") }, wording("password-on"));
  const change = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("password-change-title"), hidden: true, onclick: open("change") }, wording("password-change"));
  const switchOff = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("password-off-title"), hidden: true, onclick: open("off") }, wording("password-off"));
  const node = el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, label), says), switchOn, change, switchOff);
  /** Says whether a password is on; of `another` account it is its own, which signs it in and stays on. */
  function show(on: boolean, another = false): void {
    other = another;
    says.textContent = other ? wording("password-asked-sign-in") : on ? wording("password-is-on") : wording("password-is-off");
    switchOn.hidden = on || other;
    change.hidden = !on && !other;
    switchOff.hidden = !on || other;
  }
  return { node, show };
}

/** What the start screen says of a forgotten password: this computer's, and another account's. */
export function startForgotten(): { own: string; other: string } {
  return { own: wording("password-start-forgotten"), other: wording("password-other-forgotten") };
}

/**
 * The start screen of the account called `name`: `take` is given the password, and fails where it is not taken.
 * `action` is its button's word, `forgotten` what stands under the field, and `back`, where given, a "Back" over the
 * account.
 */
export function startScreen(
  name: string | null,
  take: (password: string) => Promise<void>,
  { action = wording("password-open"), forgotten = startForgotten().own, back }: { action?: string; forgotten?: string; back?: () => void } = {},
): HTMLElement {
  const input = el("input", { id: "start-password", className: "field f-grow minw0", type: "password", required: true, autocomplete: "current-password", ariaLabel: wording("password-password"), placeholder: wording("password-password") });
  const wrong = noticeBox();
  const form = el("form", { className: "start-form flex f-col g-8" }, el("div", { className: "flex g-8" }, input, el("button", { type: "submit", className: "btn btn-primary" }, action)), wrong);
  const run = oneAtATime(wrong);
  let wait = 0;
  let ticking: ReturnType<typeof setInterval> | undefined;
  const tick = () => {
    wait -= 1;
    const said = wrong.querySelector(".error");
    if (wait > 0 && said) {
      said.textContent = wording("error-too-many-tries", { seconds: wait });
      return;
    }
    clearInterval(ticking);
    if (wait <= 0) wrong.replaceChildren();
  };
  form.onsubmit = (event) => {
    event.preventDefault();
    clearInterval(ticking);
    wait = 0;
    const tried = () =>
      take(input.value).catch((error: unknown) => {
        if (error instanceof ApiError && error.code === "too_many_tries") wait = Number(error.details?.seconds) || 0;
        throw error;
      });
    void run(tried).then((done) => {
      if (!done) input.select();
      if (wait > 0) ticking = setInterval(tick, 1000);
    });
  };
  const called = name ?? wording("app-name");
  const node = el(
    "section",
    { className: "start-screen f-grow flex f-col ai-c jc-c" },
    el(
      "div",
      { className: "start-column flex f-col ai-c g-20" },
      el("img", { src: logo, alt: wording("app-name"), className: "start-logo" }),
      back && el("button", { type: "button", className: "textbtn", onclick: back }, wording("password-back")),
      el("span", { className: "initial", ariaHidden: "true" }, initialOf(called)),
      el("h1", null, called),
      form,
      el("p", { className: "hint start-says" }, forgotten),
    ),
  );
  queueMicrotask(() => input.focus());
  return node;
}
