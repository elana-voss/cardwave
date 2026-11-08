// Account › Server's group "Other programs", this computer's account's alone: the MCP server (server/src/api/mcp.rs),
// where other programs on this computer, such as Claude Desktop, reach an account's cards, chats and tools.
//
// The switch asks in a dialog what they can then read and do before it is switched on, and cannot be pressed while
// its change is on its way. While it is on: the address (`mcpAddress`: the page's own, only where the page was opened
// by this computer's own name, as the server answers MCP at no other) with Copy, "As account", and a line per program
// that connected with Remove, which refuses it until the switch is switched on anew. Why a change failed stands in red
// over the group.
import { wording } from "../language/language";
import { changeMcp, getMcp } from "../api/client";
import type { AccountLine } from "../api/generated/AccountLine";
import type { ChangeMcp } from "../api/generated/ChangeMcp";
import type { McpSettings } from "../api/generated/McpSettings";
import { watchAccounts } from "./accounts";
import { announce, copyText, el, failure, group, item, noticeBox, oneAtATime, reason, selectField, switchBox } from "../dom";
import { formDialog } from "../dialogs";
import { LABELS } from "../setting-labels";

/** The MCP server's address on a page opened at `at`; `null` where it was not opened on this computer. */
export function mcpAddress(at: { hostname: string; origin: string }): string | null {
  return ["127.0.0.1", "localhost", "[::1]"].includes(at.hostname) ? `${at.origin}/api/mcp` : null;
}

/** The group "Other programs". `home` is the screen its dialog stands in. */
export function mcpGroup(home: () => HTMLElement): { node: HTMLElement; left(): void } {
  const wrong = noticeBox();
  const attempt = oneAtATime(wrong);
  const box = el("div", { className: "group" });
  const label = LABELS.server.mcp;
  let now: McpSettings | null = null;
  let accounts: AccountLine[] = [];
  let busy = false;

  const store = (change: ChangeMcp, done?: string) =>
    attempt(async () => {
      busy = true;
      draw();
      try {
        now = await changeMcp(change);
        if (done) announce(done);
      } finally {
        busy = false;
        draw();
      }
    });

  /** Says what other programs can then read and do, and switches it on with "Switch on". */
  const ask = () => {
    const box = formDialog(
      home(),
      wording("mcp-ask-title"),
      [
        el(
          "p",
          { className: "hint c-ink" },
          wording("mcp-ask"),
        ),
      ],
      async () => {
        box.close();
        await store({ on: true });
      },
      wording("mcp-switch-on"),
    );
  };

  function draw(): void {
    if (!now) return;
    const settings = now;
    const toggle = switchBox({ ariaLabel: label, checked: settings.on, disabled: busy });
    toggle.onchange = () => {
      if (!toggle.checked) return void store({ on: false });
      toggle.checked = false;
      ask();
    };
    const says = wording("mcp-about");
    const lines: HTMLElement[] = [el("label", { className: "item" }, el("span", { className: "item-text" }, el("span", { className: "item-label" }, label), el("span", { className: "meta" }, says)), toggle)];
    if (settings.on) {
      const address = mcpAddress(location);
      if (address) {
        const copy = el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("mcp-copy-address"), onclick: () => void attempt(() => copyText(address)) }, wording("mcp-copy"));
        lines.push(item(LABELS.server.address, address, copy));
      }
      const choices = accounts.map((one) => ({ value: String(one.id), label: one.name }));
      const account = selectField(choices, String(settings.account), (id) => void store({ account: Number(id) }), { id: "mcp-account", disabled: busy });
      lines.push(item(el("label", { className: "item-label", htmlFor: account.field.id }, wording("mcp-as-account")), el("span", { className: "meta" }, wording("mcp-as-account-about")), account.node));
      for (const program of settings.programs) {
        const remove = el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("mcp-remove-named", { program }), disabled: busy, onclick: () => void store({ remove: program }, wording("mcp-removed", { program })) }, wording("mcp-remove"));
        lines.push(item(program, wording("mcp-connected"), remove));
      }
    }
    box.replaceChildren(...lines);
  }

  const left = watchAccounts((lines) => {
    accounts = lines;
    draw();
  });
  getMcp().then(
    (settings) => {
      now = settings;
      draw();
    },
    (error) => wrong.replaceChildren(failure(reason(error))),
  );
  const node = group(
    wording("mcp-other-programs"),
    null,
    wrong,
    box,
    el("p", { className: "hint mt-8" }, wording("mcp-only-here")),
  );
  return { node, left };
}
