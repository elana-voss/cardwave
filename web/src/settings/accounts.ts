// The accounts of the server (server/src/api/accounts.rs), as a page switches between them and signs in.
//
// `watchAccounts` is told the accounts the page can switch to, asked once and again after `rereadAccounts` (an
// account added or deleted in Account › Server). `switchItems` is the menu "Switch account" of the account's
// tabs and of the rail's account menu: the accounts, the one signed in to chosen, "Add account" for this
// computer's account, and on another device "Sign out". `switchTo` signs in to an account, asking for its password
// in a dialog where it asks for one, and the page starts anew as that account, without an address. `signInScreen`
// is what main.ts shows where the page is to sign in: the accounts to pick from, then the start screen of the one
// picked (password.ts), or the page signs in at once where it asks no password. `addAccountDialog` adds one.
import { wording } from "../language/language";
import { elsewhere } from "../account";
import { addAccount, listAccounts, signIn, signOut } from "../api/client";
import type { AccountLine } from "../api/generated/AccountLine";
import { announce, atMost, el, failure, reason, told } from "../dom";
import { formDialog, type MenuItem } from "../dialogs";
import { initialOf } from "../format";
import { icon } from "../icons";
import logo from "../logo.png";
import { startForgotten, startScreen } from "./password";

/** The most characters a name may have, as the server has it (`NAME_LIMIT` in `crates/cw-accounts/src/users.rs`). */
export const NAME_LIMIT = 40;

let known: AccountLine[] | undefined;
const watching = new Set<(lines: AccountLine[]) => void>();

/** Asks the server for the accounts anew and tells who watches. Where it does not say, what is known stays. */
export const rereadAccounts = (): Promise<void> =>
  listAccounts().then(
    (lines) => {
      known = lines;
      for (const tell of watching) tell(lines);
    },
    () => {},
  );

/** Has `tell` told the accounts: once they are known, and whenever they are read anew. Answers how it stops. */
export function watchAccounts(tell: (lines: AccountLine[]) => void): () => void {
  watching.add(tell);
  // A reading that failed is not kept: the next watcher asks again.
  if (known) tell(known);
  else void rereadAccounts();
  return () => void watching.delete(tell);
}

/** The page starts anew, without an address: the account's own first screen. */
const anew = () => location.replace(location.pathname);

/** Where a dialog of a menu stands: the screen's place, which stays when the screen changes. */
const home = () => document.querySelector<HTMLElement>("#view")!;

/** A password's field under its name. */
function passwordField(id: string, name: string, autocomplete: "current-password" | "new-password"): { input: HTMLInputElement; node: HTMLElement } {
  const input = el("input", { id, className: "field", type: "password", required: true, autocomplete });
  return { input, node: el("div", { className: "fld" }, el("label", { htmlFor: id }, name), input) };
}

/** Signs in to `line`, asking its password in a dialog where it asks for one; the page starts anew then. */
export async function switchTo(line: AccountLine): Promise<void> {
  if (!line.password) {
    await signIn(line.id);
    anew();
    return;
  }
  const password = passwordField("switch-password", wording("account-password"), "current-password");
  formDialog(
    home(),
    wording("account-switch-to", { name: line.name }),
    [el("p", { className: "dialog-says hint c-ink" }, wording("account-password-asked", { name: line.name })), password.node],
    async () => {
      await signIn(line.id, password.input.value);
      anew();
    },
    wording("account-switch-button"),
  );
  password.input.focus();
}

/** Opens the dialog that adds an account, a name and a password; `added` is told once it is. */
export function addAccountDialog(added: () => void = () => {}): HTMLDialogElement {
  const name = el("input", { id: "account-new-name", className: "field", required: true, autocomplete: "off" });
  atMost(name, NAME_LIMIT);
  const password = passwordField("account-new-password", wording("account-password"), "new-password");
  const box = formDialog(
    home(),
    wording("account-add"),
    [
      el("p", { className: "dialog-says hint c-ink" }, wording("account-add-about")),
      el("div", { className: "fld" }, el("label", { htmlFor: name.id }, wording("account-name")), name),
      password.node,
    ],
    async () => {
      const made = await addAccount(name.value, password.input.value);
      box.close();
      await rereadAccounts();
      added();
      announce(wording("account-added", { name: made.name }));
    },
    wording("account-add-button"),
  );
  name.focus();
  return box;
}

/**
 * The menu "Switch account": the accounts, the one signed in to chosen and not to be picked, then "Add account"
 * where `owner` (this computer's account) and "Sign out" on another device.
 */
export function switchItems(lines: AccountLine[], owner: boolean): MenuItem[] {
  const accounts: MenuItem[] = lines.map((line, at) => ({
    label: line.name,
    chosen: line.current,
    group: at === 0 ? wording("account-switch") : undefined,
    action: () => {
      if (!line.current) void switchTo(line).catch((error) => announce(told(error)));
    },
  }));
  const more: MenuItem[] = [];
  if (owner) more.push({ label: wording("account-add"), shape: "plus", apart: true, action: () => void addAccountDialog() });
  if (elsewhere) more.push(signOutItem(!owner));
  return [...accounts, ...more];
}

/** The menu line "Sign out", of a page on another device; `apart` under a rule. */
export const signOutItem = (apart: boolean): MenuItem => ({ label: wording("account-sign-out"), shape: "switch", apart, action: () => void signOut().then(anew) });

/** What main.ts shows where the page is to sign in: `accounts` are those it can sign in to. */
export function signInScreen(accounts: AccountLine[]): HTMLElement {
  const node = el("section", { className: "start-screen f-grow flex f-col ai-c jc-c" });
  const picture = () => el("img", { src: logo, alt: wording("app-name"), className: "start-logo" });

  /** The accounts to pick from. */
  function choose(): void {
    if (accounts.length === 0) {
      node.replaceChildren(
        el(
          "div",
          { className: "start-column flex f-col ai-c g-20" },
          picture(),
          el("h1", null, wording("account-none")),
          el("p", { className: "hint start-says" }, wording("account-none-about")),
        ),
      );
      return;
    }
    if (accounts.length === 1) return picked(accounts[0]);
    const lines = accounts.map((line) =>
      el("button", { type: "button", className: "item row w100 account-choice", onclick: () => picked(line) }, el("span", { className: "initial", ariaHidden: "true" }, initialOf(line.name)), el("span", { className: "item-text" }, el("span", { className: "item-label" }, line.name), line.local && el("span", { className: "meta" }, wording("account-this-computer"))), icon("right")),
    );
    node.replaceChildren(el("div", { className: "start-column flex f-col ai-c g-20" }, picture(), el("h1", null, wording("account-choose")), el("div", { className: "group start-accounts" }, ...lines)));
    lines[0].focus();
  }

  /** The start screen of `line`, or the page signed in at once where it asks no password; why that failed, with "Try again". */
  function picked(line: AccountLine): void {
    if (!line.password) {
      void signIn(line.id).then(anew, (error) =>
        node.replaceChildren(
          el(
            "div",
            { className: "start-column flex f-col ai-c g-20" },
            picture(),
            el("h1", null, line.name),
            failure(reason(error)),
            el("button", { type: "button", className: "btn btn-primary", onclick: () => picked(line) }, wording("account-try-again")),
            accounts.length > 1 && el("button", { type: "button", className: "textbtn", onclick: choose }, wording("account-back")),
          ),
        ),
      );
      return;
    }
    const forgotten = line.local ? startForgotten().own : startForgotten().other;
    const back = accounts.length > 1 ? choose : undefined;
    node.replaceChildren(...startScreen(line.name, (password) => signIn(line.id, password).then(anew), { action: wording("account-sign-in"), forgotten, back }).children);
  }

  choose();
  return node;
}
