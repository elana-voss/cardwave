// Settings › Tools › "Tools the AI wrote" (code mode, board "Tools the AI wrote"): the switch "Ask before a
// new tool runs" (the setting `ask_new_tools`, which has a tool shown in the chat before it is kept), then a row
// per tool the model wrote, the newest first: a box with the code drawing, its name in words (`spoken`), what it does and
// where and when it was made (`about`), its switch and "…", always shown (View code, Delete with Undo).
//
// At `#/settings/tools/written`, with the path "Settings / Tools the AI wrote". A press on a row (its name is
// the button that reaches over it, `.row-link`) or "View code" opens the panel from the right (`sheet`), the row filled meanwhile: what it
// does, where it was made and how often it ran (`used`), its code, and "Switch off" (or on) and Delete. A switch
// cannot be pressed while its change is on its way. A tool made in a chat meanwhile shows when the page is opened
// again, or the server is heard again after a drop; "Ask before a new tool runs", or a tool switched or deleted, in another window shows at once.
import { wording } from "../language/language";
import { changeSettings, deleteWrittenTool, getSettings, listWrittenTools, restoreWrittenTool, switchWrittenTool } from "../api/client";
import type { WrittenTool } from "../api/generated/WrittenTool";
import { announce, el, item, noticeBox, oneAtATime, switchBox, type View } from "../dom";
import { chatTitle } from "../chat-title";
import { menu, sheet } from "../dialogs";
import { day, spoken } from "../format";
import { icon } from "../icons";
import { emptyLine } from "../library/list-screen";

/** What a row says under a tool's name: what it does, and when and in which chat it was made. */
export function about(tool: WrittenTool): string {
  const what = tool.description.replace(/\.$/, "");
  const made = day(tool.created_at);
  return tool.chat_id === null ? wording("written-about", { what, made }) : wording("written-about-in", { what, made, chat: chatTitle(tool.chat_title ?? "") });
}

/** How often a tool ran, as its panel says it. */
export const used = (uses: number) => wording("written-used", { count: uses });

/** What the list says while the model has written no tool. */
const none = () => wording("written-none");

/** The switch "Ask before a new tool runs", which stores itself; until the setting is read it cannot be pressed. */
function askSwitch(attempt: ReturnType<typeof oneAtATime>): HTMLInputElement {
  const ask = switchBox({ ariaLabel: wording("written-ask"), disabled: true });
  ask.onchange = () =>
    void attempt(async () => {
      ask.disabled = true;
      try {
        ask.checked = (await changeSettings({ tools: { ask_new_tools: ask.checked } })).tools.ask_new_tools;
      } catch (error) {
        ask.checked = !ask.checked;
        throw error;
      } finally {
        ask.disabled = false;
      }
    });
  return ask;
}

/** A tool's sheet over `node`: what it does, where it was made, its code, and "Switch on/off" and "Delete". */
function openTool(node: HTMLElement, line: HTMLElement, tool: WrittenTool, turn: (tool: WrittenTool, on: boolean) => Promise<boolean>, remove: (tool: WrittenTool) => unknown): void {
  const where = tool.chat_id === null ? [] : [wording("written-in"), el("a", { href: `#/chats/${tool.chat_id}` }, chatTitle(tool.chat_title ?? ""))];
  const content = el(
    "div",
    { className: "written-tool flex f-col g-8" },
    el("p", { className: "hint c-ink" }, tool.description),
    el("span", { className: "meta" }, wording("written-made", { made: day(tool.created_at) }), ...where, wording("written-dot-used", { used: used(tool.uses) })),
    el("pre", { className: "code mono" }, tool.code),
  );
  const onOff = el("button", { type: "button", className: "btn btn-secondary" }, tool.on ? wording("written-switch-off") : wording("written-switch-on"));
  const del = el("button", { type: "button", className: "btn btn-danger" }, wording("common-delete"));
  const box = sheet(node, spoken(tool.name), content, el("div", null, onOff, del));
  box.querySelector(".sheet-head h2")?.classList.add("mono");
  // The tool's line stays filled while its sheet is open.
  line.classList.add("bg-fill");
  box.addEventListener("close", () => line.classList.remove("bg-fill"));
  onOff.onclick = async () => {
    if (await turn(tool, !tool.on)) box.close();
  };
  del.onclick = () => {
    box.close();
    void remove(tool);
  };
}

export function writtenToolsView(): View {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const ask = askSwitch(attempt);
  const list = el("ul", { className: "rows-plain written-tools" });
  const node = el(
    "section",
    { className: "main g-24" },
    el("header", { className: "page-head" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-written-tools")))),
    el(
      "div",
      { className: "page-col g-20" },
      el("p", { className: "hint m0" }, wording("written-intro")),
      notice,
      el("div", { className: "group" }, item(wording("written-ask"), wording("written-ask-about"), ask)),
      list,
    ),
  );
  let tools: WrittenTool[] = [];

  /** Reads the setting and the tools anew, inside an action of `attempt`'s. */
  const load = async () => {
    const [settings, written] = await Promise.all([getSettings(), listWrittenTools()]);
    ask.checked = settings.tools.ask_new_tools;
    ask.disabled = false;
    tools = written;
    list.replaceChildren(...tools.map(row));
    if (!tools.length) list.append(emptyLine(none()));
  };

  /** Switches `tool` on or off, and shows it so wherever it stands. */
  const turn = (tool: WrittenTool, on: boolean) =>
    attempt(async () => {
      await switchWrittenTool(tool.id, on);
      await load();
    });

  const remove = (tool: WrittenTool) =>
    attempt(async () => {
      await deleteWrittenTool(tool.id);
      await load();
      announce(wording("written-deleted", { name: spoken(tool.name) }), async () => {
        await attempt(async () => {
          await restoreWrittenTool(tool.id);
          await load();
        });
      });
    });

  const open = (line: HTMLElement, tool: WrittenTool) => openTool(node, line, tool, turn, remove);

  function row(tool: WrittenTool): HTMLElement {
    const toggle = switchBox({ ariaLabel: wording("written-on", { name: spoken(tool.name) }), checked: tool.on });
    toggle.onchange = () => {
      toggle.disabled = true;
      // A change not taken shows the switch as the server holds it.
      void turn(tool, toggle.checked).then((done) => {
        if (!done) toggle.checked = tool.on;
        toggle.disabled = false;
      });
    };
    const lines = [
      { label: wording("written-view-code"), shape: "code" as const, action: () => open(line, tool) },
      { label: wording("common-delete"), shape: "trash" as const, danger: true, apart: true, action: () => void remove(tool) },
    ];
    const line: HTMLElement = el(
      "li",
      { className: "item row rel written-row" },
      el("span", { className: "icover" }, icon("code", 16)),
      el(
        "div",
        { className: "item-text" },
        el("button", { type: "button", className: "row-link medium", onclick: () => open(line, tool) }, spoken(tool.name)),
        el("span", { className: "meta" }, about(tool)),
      ),
      toggle,
      menu(wording("common-more"), lines),
    );
    return line;
  }

  void attempt(load);
  return { node: node, onEvent: (event) => void ((event.type === "settings" || event.type === "written_tools") && attempt(load)), onConnected: () => void attempt(load) };
}
