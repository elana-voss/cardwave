// Account › Server, at `#/account/server`, this computer's account's alone (the tab is not shown to another).
//
// The group "Other devices": the switch "Reachable in the home network" (`setNetwork`), which asks in a dialog
// before it is switched on, and while it is on the
// line "Address" with the address another device opens and "Copy", and where Tailscale is up here the line "From
// anywhere" with its address and "Copy"; under the group that it stays inside the network, and while it is on with
// no Tailscale address, how Tailscale opens it from anywhere, its site a link. The group "Other programs" is mcp.ts's. The group "Accounts", with "Add account" in its line (accounts.ts): a line per account, its letter, its
// name and, of this computer's, "This computer · can add and remove accounts"; another's has a menu with "Reset password" (a dialog) and "Delete account", which asks in the
// menu's place as the Trash does and deletes the account with all it holds. Why something failed stands in red
// over the group it is of.
import { wording } from "../language/language";
import { rereadAccounts, addAccountDialog, watchAccounts } from "../settings/accounts";
import { deleteAccount, getNetwork, resetPassword, setNetwork } from "../api/client";
import type { AccountLine } from "../api/generated/AccountLine";
import type { NetworkState } from "../api/generated/NetworkState";
import { announce, copyText, el, failure, group, item, noticeBox, oneAtATime, reason, switchBox, type View } from "../dom";
import { formDialog, menuDeleting } from "../dialogs";
import { initialOf } from "../format";
import { icon } from "../icons";
import { mcpGroup } from "../settings/mcp";
import { accountTabs } from "../shell/account-tabs";
import { LABELS } from "../setting-labels";

/** Tailscale's site as every language names it in "server-tailscale", and where its link leads. */
const TAILSCALE_SITE = "tailscale.com";
const TAILSCALE_DOWNLOAD = "https://tailscale.com/download";

/** The group "Other devices". `home` is the screen its dialog stands in. */
export function devicesGroup(home: () => HTMLElement): HTMLElement {
  const wrong = noticeBox();
  const attempt = oneAtATime(wrong);
  const label = LABELS.server.network;
  const toggle = switchBox({ ariaLabel: label, disabled: true });
  const at = el("span", { className: "meta" });
  const copy = el("button", { type: "button", className: "btn btn-secondary on-box" }, wording("server-copy"));
  const address = item(LABELS.server.address, at, copy);
  const far = el("span", { className: "meta" });
  const copyFar = el("button", { type: "button", className: "btn btn-secondary on-box" }, wording("server-copy"));
  const anywhere = item(wording("server-anywhere"), far, copyFar);
  const inside = el("p", { className: "hint mt-8" }, wording("server-inside"));
  // Tailscale's site in the hint is a link; in the desktop app it opens in the browser (desktop's `on_new_window`).
  const [before, after] = wording("server-tailscale").split(TAILSCALE_SITE);
  const site = el("a", { href: TAILSCALE_DOWNLOAD, target: "_blank", rel: "noopener noreferrer" }, TAILSCALE_SITE);
  const tailscale = el("p", { className: "hint mt-8" }, before ?? "", ...(after === undefined ? [] : [site, after]));
  const show = (now: NetworkState) => {
    toggle.checked = now.on;
    toggle.disabled = false;
    address.hidden = !now.on;
    at.textContent = now.address ?? wording("server-no-network");
    copy.disabled = !now.address;
    anywhere.hidden = !(now.on && now.anywhere);
    far.textContent = now.anywhere ?? "";
    inside.hidden = !anywhere.hidden;
    tailscale.hidden = !now.on || !!now.anywhere;
  };
  show({ on: false, address: null, anywhere: null });
  toggle.disabled = true;
  // The switch cannot be pressed while its change is on its way, so it never shows what the server does not hold.
  const store = (on: boolean) =>
    attempt(async () => {
      toggle.disabled = true;
      try {
        show(await setNetwork(on));
      } catch (error) {
        toggle.checked = !on;
        toggle.disabled = false;
        throw error;
      }
    });
  toggle.onchange = () => {
    if (!toggle.checked) return void store(false);
    // Switched on, it asks first; until "Switch on" it stays off.
    toggle.checked = false;
    const box = formDialog(
      home(),
      label,
      [el("p", { className: "hint c-ink" }, wording("server-switch-on-about"))],
      async () => {
        box.close();
        toggle.checked = true;
        await store(true);
      },
      wording("server-switch-on"),
    );
  };
  copy.onclick = () => attempt(() => copyText(at.textContent ?? ""));
  copyFar.onclick = () => attempt(() => copyText(far.textContent ?? ""));
  getNetwork().then(show, (error) => wrong.replaceChildren(failure(reason(error))));
  const switchLine = el("label", { className: "item" }, el("span", { className: "item-text" }, el("span", { className: "item-label" }, label), el("span", { className: "meta" }, wording("server-network-about"))), toggle);
  return group(
    wording("server-other-devices"),
    null,
    wrong,
    el("div", { className: "group" }, switchLine, address, anywhere),
    inside,
    tailscale,
  );
}

/** The group "Accounts". `home` is the screen its dialogs stand in. */
function accountsGroup(home: () => HTMLElement): { node: HTMLElement; left(): void } {
  const wrong = noticeBox();
  const attempt = oneAtATime(wrong);
  const box = el("div", { className: "group" });
  const add = el("button", { type: "button", className: "btn btn-quiet", onclick: () => void addAccountDialog() }, icon("plus", 16), wording("server-add-account"));

  /** One account's line. */
  function line(account: AccountLine): HTMLElement {
    // Of the others nothing is said under the name: no "Password set" (second review of the v4 boards).
    const round = el("span", { className: "initial initial-md fs-small", ariaHidden: "true" }, initialOf(account.name));
    if (account.local) return el("div", { className: "item" }, round, el("div", { className: "item-text" }, el("span", { className: "item-label" }, account.name), el("span", { className: "meta" }, wording("server-owner"))));
    /** Deletes the account, once asked under the line, which cannot be taken back. */
    const remove = () =>
      void attempt(async () => {
        await deleteAccount(account.id);
        await rereadAccounts();
        announce(wording("server-deleted", { name: account.name }));
      });
    const more = menuDeleting(wording("server-more-of", { name: account.name }), [{ label: wording("server-reset-password"), shape: "edit", action: () => reset(account) }], {
      label: wording("server-delete-account"),
      question: () => wording("server-delete-ask"),
      yes: wording("common-delete"),
      action: remove,
    });
    const tools = el("div", { className: "flex" }, more);
    const node = el("div", { className: "item" }, round, el("div", { className: "item-text" }, el("span", { className: "item-label" }, account.name)), tools);
    return node;
  }

  /** The dialog that gives `account` another password. */
  function reset(account: AccountLine): void {
    const password = el("input", { id: "reset-password", className: "field", type: "password", required: true, autocomplete: "new-password" });
    const box = formDialog(
      home(),
      wording("server-reset-title", { name: account.name }),
      [
        el("p", { className: "hint c-ink" }, wording("server-reset-about")),
        el("div", { className: "fld" }, el("label", { htmlFor: password.id }, wording("server-new-password")), password),
      ],
      async () => {
        await resetPassword(account.id, password.value);
        box.close();
        announce(wording("server-reset-done", { name: account.name }));
      },
      wording("server-reset"),
    );
    password.focus();
  }

  const left = watchAccounts((lines) => box.replaceChildren(...lines.map(line)));
  void rereadAccounts();
  const node = group(wording("server-accounts"), add, wrong, box);
  return { node, left };
}

export function serverView(): View {
  const accounts = accountsGroup(() => node);
  const programs = mcpGroup(() => node);
  const tabs = accountTabs("#/account/server");
  const node: HTMLElement = el(
    "section",
    { className: "main g-24" },
    tabs.node,
    el("div", { className: "page-col" }, devicesGroup(() => node), programs.node, accounts.node),
  );
  return {
    node: node,
    left: () => {
      accounts.left();
      programs.left();
      tabs.left();
    },
  };
}
