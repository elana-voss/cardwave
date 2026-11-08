// The tabs the account's pages have in their bar (`.page-head`, the design system's) (settings.ts, profile.ts, server.ts), with "Switch account" at
// their right where there are other accounts. Server is this computer's account's alone.
import { wording } from "../language/language";
import { account } from "../account";
import { switchItems, watchAccounts } from "../settings/accounts";
import type { AccountLine } from "../api/generated/AccountLine";
import { el, tabs } from "../dom";
import { menuOn } from "../dialogs";
import { icon } from "../icons";
import { accountPages, SERVER } from "./rail";


/**
 * The account's tabs: the open one is the screen's, by its address, the others lead to their pages; Server is this computer's
 * account's alone. "Switch account" stands at their right while there are other accounts. `left` ends the watching
 * of the accounts, which the screen does when it is left.
 */
export function accountTabs(open: string): { node: HTMLElement; left(): void } {
  const pages = accountPages();
  const nav = tabs(
    wording("account-sections"),
    pages.map(([name, href]) => ({ name, href, open: href === open })),
  );
  const server = nav.children[pages.findIndex(([, href]) => href === SERVER)] as HTMLElement;
  server.hidden = open !== SERVER;
  const switching = el("div", { className: "switch-account" });
  let owner = false;
  let lines: AccountLine[] = [];
  const draw = () => {
    const button = el("button", { type: "button", className: "quiet btn btn-quiet" }, icon("switch", 16), wording("account-switch"));
    switching.replaceChildren(...(lines.length > 1 ? [menuOn(button, switchItems(lines, owner), "end")] : []));
  };
  void account().then(({ local }) => {
    owner = local;
    server.hidden = !local;
    draw();
  }, () => {});
  const left = watchAccounts((now) => {
    lines = now;
    draw();
  });
  return { node: el("header", { className: "account-tabs page-head wrap" }, nav, switching), left };
}
