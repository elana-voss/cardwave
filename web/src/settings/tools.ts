// The tools the chat model may call, in two groups (`toolsGroup`, its lines by `toolLines`): Settings' "Tools" holds
// Web alone; Settings › Advanced's "Tools for the AI" the rest, then the links to "Tools the AI wrote",
// views/written-tools.ts, which says `writtenSays`, and to "Coding team", views/coding-team.ts (the owner,
// 2026-11-15, milestone 144). What a chat shows while a call waits is chat/tool-ask.ts's.
//
// A switch line is the server's setting, which cannot be pressed while its change is on its way, so it never shows
// what the server does not hold. Files, Commands, the two "Ask before" lines and Folder are this computer's
// account's alone; an "Ask before" line shows while its tool is on. Files and Commands cannot be switched on
// without a folder, nor Image generation without an image model. Cardwave is the app's own tools, each change
// asked first, without the switch for the chat. Dice, off at first, the dice the model rolls in every chat (the owner,
// 2026-10-23), then Names for new characters, also off at first (Claude, 161), the last switches.
import { wording } from "../language/language";
import { changeSettings, getImages, getSettings, listWrittenTools } from "../api/client";
import type { ChangeTools } from "../api/generated/ChangeTools";
import type { CodingTeam } from "../api/generated/CodingTeam";
import type { Tools } from "../api/generated/Tools";
import { account } from "../account";
import { shape, teamLabel } from "../chat/coding";
import { el, failure, group, item, link, noticeBox, oneAtATime, reason, switchBox } from "../dom";
import { folderDialog } from "../dialogs";
import { LABELS } from "../setting-labels";

type Switch = "web" | "files" | "ask_writes" | "commands" | "ask_commands" | "pictures" | "app" | "dice" | "names";

/** What the link to the tools the model wrote says: how many there are, and whether a new one asks first. */
export function writtenSays(count: number, ask: boolean): string {
  return ask ? wording("tools-written-ask", { count }) : wording("tools-written-free", { count });
}

/** A switch line of the group: what it sets, its name, what it says, and whether it cannot be pressed. */
export type ToolLine = { key: Switch; label: string; says: string; off: boolean };

/** Which group: Settings' "Tools" (Web) or Advanced's "Tools for the AI" (the rest). */
export type ToolsPart = "web" | "ai";

/** The switch lines of the part, for this computer's account (`local`) or another, with an image model or not. */
export function toolLines(tools: Tools, local: boolean, image: boolean, part: ToolsPart): ToolLine[] {
  if (part === "web") return [{ key: "web", label: LABELS.settings.web, says: wording("tools-web"), off: false }];
  const folder = tools.folder;
  const needs = (on: boolean, says: string): Pick<ToolLine, "says" | "off"> => (folder || on ? { says, off: false } : { says: wording("tools-folder-first"), off: true });
  const lines: ToolLine[] = [];
  if (local) {
    lines.push({ key: "files", label: LABELS.advanced.files, ...needs(tools.files, wording("tools-files", { folder: folder ?? "" })) });
    if (tools.files) lines.push({ key: "ask_writes", label: wording("tools-ask-writes"), says: wording("tools-ask-writes-says"), off: false });
    lines.push({ key: "commands", label: LABELS.advanced.commands, ...needs(tools.commands, wording("tools-commands", { folder: folder ?? "" })) });
    if (tools.commands) lines.push({ key: "ask_commands", label: wording("tools-ask-commands"), says: wording("tools-ask-commands-says"), off: false });
  }
  lines.push({
    key: "pictures",
    label: LABELS.advanced.imageGeneration,
    says: image || tools.pictures ? wording("tools-pictures") : wording("tools-pictures-first"),
    off: !image && !tools.pictures,
  });
  lines.push({ key: "app", label: LABELS.advanced.app, says: wording("tools-app"), off: false });
  lines.push({ key: "dice", label: LABELS.advanced.dice, says: wording("tools-dice"), off: false });
  lines.push({ key: "names", label: LABELS.advanced.names, says: wording("tools-names"), off: false });
  return lines;
}

/**
 * The group of the part, which says why a change was not taken over its lines. `read` reads the
 * settings and the image model anew.
 */
export function toolsGroup(home: () => HTMLElement, part: ToolsPart): { node: HTMLElement; read(): void } {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const box = el("div", { className: "group" });
  let tools: Tools | null = null;
  let coding: CodingTeam | null = null;
  let local = false;
  let image = false;
  let written = 0;
  let busy = false;
  const change = (to: ChangeTools) =>
    attempt(async () => {
      busy = true;
      draw();
      try {
        tools = (await changeSettings({ tools: to })).tools;
      } finally {
        busy = false;
        draw();
      }
    });
  const chooseFolder = () =>
    folderDialog(home(), wording("label-settings-folder"), tools?.folder ?? "", wording("tools-folder-example"), wording("tools-folder-says"), async (folder) => {
      tools = (await changeSettings({ tools: { folder } })).tools;
      draw();
    });
  function draw(): void {
    if (!tools) return;
    const lines = toolLines(tools, local, image, part).map(({ key, label, says, off }) => {
      const toggle = switchBox({ ariaLabel: label, checked: tools![key] as boolean, disabled: busy || off });
      toggle.onchange = () => void change({ [key]: toggle.checked });
      return item(label, says, toggle);
    });
    if (local && part === "ai") {
      const button = el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("tools-change-folder"), onclick: chooseFolder }, tools.folder ? wording("tools-change") : wording("tools-choose"));
      lines.push(item(LABELS.advanced.folder, tools.folder ?? wording("tools-none-chosen"), button));
    }
    if (part === "web") return box.replaceChildren(...lines);
    const { workers, audit } = shape(coding!, coding!.team);
    box.replaceChildren(
      ...lines,
      link("#/settings/tools/written", LABELS.advanced.written, writtenSays(written, tools.ask_new_tools)),
      // The team works on this computer's files (Claude).
      local ? link("#/settings/tools/coding", LABELS.advanced.coding, teamLabel(coding!.team, workers, audit)) : "",
    );
  }
  const read = () => {
    Promise.all([getSettings(), getImages(), account(), listWrittenTools()]).then(
      ([settings, model, me, made]) => {
        tools = settings.tools;
        coding = settings.coding;
        image = model !== null;
        local = me.local;
        written = made.length;
        draw();
      },
      (error) => notice.replaceChildren(failure(reason(error))),
    );
  };
  read();
  return { node: group(part === "web" ? wording("tools-title") : wording("tools-for-ai"), null, notice, box), read };
}
