// Pictures in the chat: one a model made (`pictureOf`), in its message's text's place, with its menu, a round "…"
// at its corner on hover (always on touch): Change prompt, Save picture, Delete (board "Chat · a picture's menu").
// Change prompt puts the words it was made from in a field under it, dimmed (`s.repicturing`); "Make again" makes
// it anew as another version of the message, which the composer's Stop stops, as it does "Make a picture". And
// what the user attached to a message (`attachedTo`), above its bubble: a picture as a 120 × 90 tile, a document as
// a grey line with its name and kind (board "Chat · thinking and attachments").
import type { Attachment } from "../api/generated/Attachment";
import type { ChatCharacter } from "../api/generated/ChatCharacter";
import type { MessageView } from "../api/generated/MessageView";
import { attachmentUrl, avatarUrl, makeAgain, pictureUrl } from "../api/client";
import { isArt } from "../art";
import { el } from "../dom";
import { dialog, menuOn, type MenuItem } from "../dialogs";
import { saveFrom } from "../storage";
import { icon } from "../icons";
import { deleteItem, documentKind } from "../library/library-actions";
import { failed, idle, show, startDrafting, type Screen } from "./screen";
import { wording } from "../language/language";

/** The words a picture was made from, which its message's text holds for the model. */
export const wordsOf = (message: MessageView) => message.content.replace(/^\*\(sends a picture: ([^]*)\)\*$/, "$1");

/**
 * A picture a model made, at most 350 × 512 px; a grey box of that size until it has come. A press opens it
 * full size in a dialog with "Save" (the owner, 2026-10-15). `remove` deletes its message.
 */
export function pictureOf(s: Screen, message: MessageView, remove: () => void): HTMLElement {
  const src = pictureUrl(message.id);
  const alt = wordsOf(message);
  const shown = el("img", { className: "picture", src, alt });
  shown.onload = () => shown.classList.add("loaded");
  const name = `picture-${message.id}.png`;
  if (s.repicturing?.id === message.id) return changing(s, message, shown);
  const open = () =>
    dialog(
      s.node,
      wording("label-profile-picture"),
      el("div", { className: "picture-whole" }, el("img", { src, alt })),
      el("div", { className: "dfoot" }, el("button", { type: "button", className: "btn btn-primary", onclick: () => saveFrom(src, name) }, wording("common-save"))),
    ).classList.add("picture-dialog");
  const picture = el("div", { className: "painted-picture" }, el("button", { type: "button", className: "picture-open", ariaLabel: wording("pictures-open-the-picture"), onclick: open }, shown));
  // A chat in the Trash, or one in which something is written, has the picture only read.
  if (!message.complete || s.view!.chat.trashed) return picture;
  const still = !idle(s);
  const items: MenuItem[] = [
    {
      label: wording("pictures-change-prompt"),
      shape: "edit",
      off: still,
      action: () => {
        s.repicturing = { id: message.id, words: alt };
        s.render();
        s.list.querySelector<HTMLTextAreaElement>(".repicture textarea")?.focus();
      },
    },
    { label: wording("pictures-save-picture"), shape: "export", action: () => void saveFrom(src, name) },
    { ...deleteItem(remove), off: still },
  ];
  const button = el("button", { type: "button", className: "btn btn-icon btn-sm on-box c-ink", ariaLabel: wording("pictures-picture-options") }, icon("more"));
  const menu = menuOn(button, items, "end");
  menu.classList.add("picture-menu");
  picture.append(menu);
  return picture;
}

/** The picture dimmed, with the words it was made from in a field under it, "Make again" and Cancel. */
function changing(s: Screen, message: MessageView, shown: HTMLImageElement): HTMLElement {
  const words = s.repicturing!.words;
  const area = el("textarea", { className: "field", value: words, rows: 4, ariaLabel: wording("pictures-prompt") });
  area.oninput = () => {
    if (s.repicturing) s.repicturing.words = area.value;
  };
  const making = s.drafting?.picture === true && s.drafting.again === message.id;
  area.readOnly = making;
  const again = el("button", { type: "button", className: "btn btn-primary btn-sm", disabled: making || !area.value.trim(), onclick: () => void remake(s, message) }, wording("pictures-make-again"));
  area.addEventListener("input", () => (again.disabled = !area.value.trim()));
  const back = () => {
    s.repicturing = null;
    s.render();
  };
  const cancel = el("button", { type: "button", className: "btn btn-secondary btn-sm", disabled: making, onclick: back }, wording("common-cancel"));
  shown.classList.add("dimmed");
  return el("div", { className: "repicture flex f-col g-8" }, shown, area, el("div", { className: "flex g-8" }, again, cancel));
}

/** Makes the picture anew of the words in its field, as another version of its message. Stopped, or failing, it stays as it was. */
async function remake(s: Screen, message: MessageView): Promise<void> {
  const words = s.repicturing?.words.trim();
  if (!words) return;
  const mine = startDrafting(s, false, true, message.id);
  if (!mine) return;
  try {
    const made = await makeAgain(message.id, { words }, mine.stop.signal);
    s.repicturing = null;
    if (s.drafting === mine) s.drafting = null;
    show(s, made);
  } catch (error) {
    if (!mine.stop.signal.aborted) failed(s, error);
  }
  if (s.drafting === mine) s.drafting = null;
  s.render();
}

/** One attachment: a picture's tile, `small` over the message field, else a document's grey line. */
export function attachmentNode(attached: Attachment, small = false): HTMLElement {
  if (attached.picture) return el("img", { className: small ? "attached-picture small" : "attached-picture", src: attachmentUrl(attached.id), alt: attached.name });
  return el(
    "div",
    { className: small ? "attached-file file small" : "attached-file file" },
    icon("document", 20),
    el("div", { className: "attached-name flex f-col minw0" }, el("span", { className: "ellipsis" }, attached.name), el("span", { className: "meta fs-caption" }, documentKind(attached.name))),
  );
}

/** What the user attached to a message, over its bubble: none for a message without. */
export const attachedTo = (message: MessageView): HTMLElement | null =>
  message.attachments.length ? el("div", { className: "att attachments" }, ...message.attachments.map((attached) => attachmentNode(attached))) : null;

/**
 * A character's picture in a round: its avatar, or else its card's picture, of which the round shows the top.
 * A card without art, or a picture that does not come, has the grey round alone, a `span` in the picture's
 * place, as an `img` without a picture is drawn as a broken one. With `named` it names the character while pointed at.
 */
export function avatar(character: ChatCharacter, size = "ava", named = false): HTMLElement {
  const title = named ? character.name : "";
  const shown = el("img", { className: `${size} avatar`, src: avatarUrl(character), alt: "", title });
  const none = () => shown.replaceWith(el("span", { className: `${size} avatar bg-fill`, title }));
  shown.onload = () => {
    if (!isArt(shown)) none();
  };
  shown.onerror = none;
  return shown;
}
