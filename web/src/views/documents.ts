// Knowledge › Documents: the documents of the user's chats and characters, the newest first, made as Knowledge ›
// Memories (docs/design.md, "Knowledge › Documents"). A document is added by "Attach picture or document" in a chat's
// "+" (chat/composer.ts), "Add document" in a card's "…" (`documentItem` of library-actions.ts), and by "Add document" at the header's right (`addAnywhere`),
// which asks for a file and then, in a dialog, for the chat or character it is for.
//
// Under the search a grey line says what documents do. A row (`.document-row`) is the document's name without its
// file's ending, under it in grey its kind, its words and the chat or the character it is for (a link); while Search is not set
// up, one line over the list says so, with a link to Settings. Empty, the list offers "Add document" too. Its "…" has Delete,
// which asks nothing and has the notice's Undo. The search is the page's own, over the list it read: every word must
// be in the name or in what it is for. A change anywhere (the event `documents`, also when the model has read one),
// and the server heard again after a drop, have the list read anew.
import { addCardDocument, addChatDocument, deleteDocument, getSearchModel, listCards, listChats, listDocuments, restoreDocument } from "../api/client";
import type { DocumentView } from "../api/generated/DocumentView";
import { announce, el, latest, noticeBox, oneAtATime, searchField, selectField, type View } from "../dom";
import { chatTitle } from "../chat-title";
import { formDialog, menu } from "../dialogs";
import { icon } from "../icons";
import { emptyLine, pageTitle } from "../library/list-screen";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";
import { documentKind } from "../library/library-actions";

/** What the list was last searched for. Kept while the app runs. */
const asked = { q: "" };

/** A document's name as its row shows it: without its file's ending ("Castle history.md" is "Castle history"). */
export const shownName = (name: string) => name.replace(/\.[A-Za-z0-9]{1,5}$/, "");

/** What a row says of a document under its name: its kind, its words, then whom it is for (`owner`). */
function about(document: DocumentView, owner: (string | HTMLElement)[]): (string | HTMLElement)[] {
  return [documentKind(document.name), " · ", wording("documents-words", { count: document.words }), " · ", ...owner];
}

/**
 * Asks for a file of the kinds a document is read from, then in the dialog "Add document" over `home` for the chat
 * or the character it is for, and gives it to that one; `added` is told once it is there.
 */
function addAnywhere(home: HTMLElement, run: (action: () => Promise<void>) => Promise<unknown>, added: () => Promise<void>): void {
  const field = el("input", { type: "file", accept: ".txt,.md,.markdown,.pdf,.docx", hidden: true });
  field.oncancel = () => field.remove();
  field.onchange = () =>
    void run(async () => {
      const [file] = field.files ?? [];
      field.remove();
      if (!file) return;
      const [chats, cards] = await Promise.all([listChats(), listCards()]);
      const group = (label: string, options: [string, string][]) => options.map(([value, text], at) => ({ value, label: text, group: at === 0 ? label : undefined }));
      const choices = [
        ...group(wording("page-chats"), chats.map((chat) => [`chat:${chat.id}`, chatTitle(chat.title)])),
        ...group(wording("page-characters"), cards.map((card) => [`card:${card.id}`, cardTitle(card.title)])),
      ];
      // The first is chosen to begin with, as a required select has it.
      const pick = selectField(choices, choices[0]?.value ?? "", () => {}, { id: "document-for" });
      const fields = [el("p", { className: "dialog-says hint c-ink" }, wording("library-actions-quoted", { name: file.name })), el("div", { className: "fld" }, el("label", { htmlFor: pick.field.id }, wording("card-figure-for")), pick.node)];
      const box = formDialog(
        home,
        wording("library-actions-add-document"),
        fields,
        async () => {
          const [kind, id] = pick.value.split(":");
          const to = kind === "chat" ? wording("documents-the-chat") : cardTitle(cards.find((card) => card.id === Number(id))!.title);
          const made = await (kind === "chat" ? addChatDocument : addCardDocument)(Number(id), file);
          box.close();
          announce(wording("library-actions-document-added", { name: made.name, to }));
          await added();
        },
        wording("account-add-button"),
      );
    });
  home.append(field);
  field.click();
}

/** What the chat or the character a document is for is called in its row. */
const ownerName = (document: DocumentView) => (document.chat_id === null ? document.owner_name : chatTitle(document.owner_name));

export function documentsView(): View {
  const list = el("ul", { className: "rows-plain" });
  const unread = el("p", { className: "meta m0", hidden: true }, wording("documents-found-by-meaning-once"), " ", el("a", { href: "#/settings" }, wording("documents-set-up-search")));
  const notice = noticeBox();
  let all: DocumentView[] = [];
  const draw = () => {
    const words = asked.q.toLowerCase().split(/\s+/).filter(Boolean);
    const found = all.filter((document) => words.every((word) => `${document.name} ${ownerName(document)}`.toLowerCase().includes(word)));
    list.replaceChildren(...found.map(row));
    if (found.length) return;
    list.append(all.length ? emptyLine(wording("documents-no-document-found")) : emptyLine(wording("documents-no-documents-yet-a"), [{ label: wording("library-actions-add-document"), go: () => addAnywhere(node, attempt, load) }]));
  };
  const search = searchField(wording("documents-search-documents"), wording("documents-name-chat-or-character"), asked, draw, "search-list");
  const add = el("button", { type: "button", className: "btn btn-quiet", onclick: () => addAnywhere(node, attempt, load) }, icon("plus", 16), wording("library-actions-add-document"));
  const node: HTMLElement = el("section", { className: "main main-list knowledge" }, el("header", { className: "pbar" }, pageTitle(wording("page-documents")), el("div", { className: "flex ai-c g-8" }, add)), el("div", { className: "flex g-12" }, search), el("p", { className: "meta m0" }, wording("documents-what-they-are")), notice, unread, list);
  const attempt = oneAtATime(notice);
  const load = latest(notice, listDocuments, (documents) => {
    all = documents;
    draw();
    getSearchModel().then(
      (model) => (unread.hidden = !all.length || model.state === "ready"),
      // Without the search model's state the line stays as it was: the list itself is what matters here.
      () => undefined,
    );
  });

  function row(document: DocumentView): HTMLElement {
    const remove = () =>
      attempt(async () => {
        await deleteDocument(document.id);
        await load();
        announce(wording("documents-document-deleted"), async () => {
          await restoreDocument(document.id);
          await load();
        });
      });
    const owner =
      document.chat_id === null
        ? [wording("documents-for-the-character"), el("a", { href: `#/library/${document.card_id}` }, ownerName(document))]
        : [wording("documents-for-the-chat"), el("a", { href: `#/chats/${document.chat_id}` }, ownerName(document))];
    return el(
      "li",
      { className: "item row item-roomy ai-s document-row" },
      el("span", { className: "icover icover-sq" }, icon("document")),
      el("div", { className: "item-text item-text-spaced" }, el("span", { className: "medium" }, shownName(document.name)), el("span", { className: "meta" }, ...about(document, owner))),
      el("div", { className: "reveal flex" }, menu(wording("common-more"), [{ label: wording("common-delete"), shape: "trash", danger: true, action: () => void remove() }])),
    );
  }

  void load();
  return {
    node: node,
    onEvent: (event) => void (event.type === "documents" && load()),
    onConnected: () => void load(),
  };
}
