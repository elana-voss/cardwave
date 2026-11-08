// The group "Prompt presets" of the account's page "Advanced": a system prompt and an author's note kept under a
// name, of which one is in use for every chat that does not choose its own (the chat's side panel).
//
// `promptPresetsGroup` is `.settings-group.prompt-presets`, made as the model presets' group (presets.ts), with its lines
// `.item.preset` and their tools `.reveal.preset-tools`. The first line is "Default", the card's own prompt,
// which no preset in use means; its menu has Duplicate alone, which makes an empty preset. A preset's line says
// under its name what it changes (`about`); its menu has Edit, which opens its editor (views/prompt-preset.ts),
// Duplicate and Delete, which asks under its line and cannot be taken back. "New preset" opens the editor
// empty. "Use" says so in the notice, with Undo back to the one in use before. The list is read anew after
// every change, and the line acted on has the focus then (`after`, by `data-preset`, "default" for Default).
import { wording } from "../language/language";
import { deletePromptPreset, duplicateDefaultPrompt, duplicatePromptPreset, listPromptPresets, usePromptPreset } from "../api/client";
import type { PromptPreset } from "../api/generated/PromptPreset";
import type { PromptTexts } from "../api/generated/PromptTexts";
import { announce, el, item, latest, noticeBox, oneAtATime } from "../dom";
import { askUnder, menu } from "../dialogs";
import { icon } from "../icons";

/** The address of a prompt preset's editor; `new` for one not made yet. */
export const editorOf = (id: number | "new") => `#/settings/advanced/prompts/${id}`;

/** What a prompt preset's line says under its name: what it changes of the card's prompt. */
export function about({ system_prompt, authors_note, authors_note_depth }: PromptTexts): string {
  const depth = authors_note_depth;
  const system = system_prompt.trim() !== "";
  const note = authors_note.trim() !== "";
  if (system && note) return wording("prompt-system-note", { depth });
  if (system) return wording("prompt-system");
  return note ? wording("prompt-note", { depth }) : wording("prompt-as-card");
}

/** Why no preset may be called `typed`: Default, the card's own prompt, is called so; none where it may. */
export function refusedName(typed: string): string | null {
  const name = wording("prompt-default");
  return typed.trim() === name ? wording("prompt-default-name", { name }) : null;
}

/** The group "Prompt presets". */
export function promptPresetsGroup(): { node: HTMLElement; read(): Promise<void> } {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const add = el("button", { type: "button", className: "btn btn-quiet", onclick: () => (location.hash = editorOf("new")) }, icon("plus", 16), wording("preset-new"));
  const box = el("div", { className: "group" });
  const node = el("section", { className: "settings-group prompt-presets" }, el("div", { className: "gh" }, el("h2", null, wording("prompt-presets")), add), notice, box);

  /** Says what was done, unless the page was left meanwhile. */
  const say: typeof announce = (...said) => {
    if (node.isConnected) announce(...said);
  };

  /** The one in use, as the list said last: `null` for Default. */
  let using: number | null = null;
  const read = latest(notice, listPromptPresets, (presets) => {
    using = presets.find((preset) => preset.in_use)?.id ?? null;
    box.replaceChildren(defaultRow(using === null), ...presets.map(row));
  });

  /** Reads the list anew after something was done to the line `id` ("default" for Default), whose "More" has the focus then; else "New preset" has it. */
  async function after(id: number | "default" | null): Promise<void> {
    await read();
    (box.querySelector<HTMLElement>(`[data-preset="${id}"] .menu > button`) ?? add).focus();
  }

  /** Puts `id` in use, with Undo back to the one in use before. */
  const use = (id: number | null, name: string) =>
    void attempt(async () => {
      const before = using;
      await usePromptPreset(id);
      await after(id ?? "default");
      say(wording("preset-using", { name }), async () => {
        await usePromptPreset(before);
        await read();
      });
    });

  /** Makes a copy by `made`, which the line made has the focus after. */
  const copy = (made: () => Promise<PromptPreset>) =>
    void attempt(async () => {
      const preset = await made();
      await after(preset.id);
      say(wording("preset-added", { name: preset.name }));
    });

  /** A line with its name, what is said under it, and its tools. */
  function line(name: string, inUse: boolean, said: string, key: string, more: HTMLElement, id: number | null): { line: HTMLElement; tools: HTMLElement } {
    const button = el("button", { type: "button", className: "btn btn-secondary", onclick: () => use(id, name) }, wording("common-use"));
    const tools = el("div", { className: "reveal preset-tools flex g-4" }, !inUse && button, more);
    const line = item(el("span", { className: "item-label" }, name, inUse && el("span", { className: "meta" }, wording("common-in-use"))), el("span", { className: "meta" }, said), tools);
    line.classList.add("preset", "row");
    line.dataset.preset = key;
    return { line, tools };
  }

  function defaultRow(inUse: boolean): HTMLElement {
    const more = menu(wording("common-more"), [{ label: wording("common-duplicate"), shape: "copy", action: () => copy(duplicateDefaultPrompt) }]);
    return line(wording("prompt-default"), inUse, wording("prompt-as-card"), "default", more, null).line;
  }

  function row(preset: PromptPreset): HTMLElement {
    const more = menu(wording("common-more"), [
      { label: wording("common-edit"), shape: "edit", action: () => (location.hash = editorOf(preset.id)) },
      { label: wording("common-duplicate"), shape: "copy", action: () => copy(() => duplicatePromptPreset(preset.id)) },
      { label: wording("common-delete"), shape: "trash", danger: true, apart: true, action: () => ask() },
    ]);
    const { line: node, tools } = line(preset.name, preset.in_use, about(preset), String(preset.id), more, preset.id);

    /** Asks under the line whether the preset is to be deleted, which cannot be taken back. */
    function ask(): void {
      const remove = () =>
        void attempt(async () => {
          await deletePromptPreset(preset.id);
          await after(null);
          say(wording("preset-deleted", { name: preset.name }));
        });
      askUnder(tools, more.querySelector("button")!, wording("preset-delete-ask"), wording("common-delete"), remove);
    }
    return node;
  }

  return { node, read };
}
