// A lorebook a card brings itself, where the library's list and its editor offer it: its address
// (`lorebookAddress`, which names a library lorebook's too) and the lines Copy to library and Move to library
// of its "…" (`ownLines`). Copied, the card keeps its own and the library has a separate lorebook, which Undo
// deletes for good; moved, the library has it and the card uses it from there, and Undo puts it back into the
// card (`moveBack`).
import { changeLorebook, copyLorebook, deleteLorebook, moveBack, moveLorebook, type LoreOf } from "../api/client";
import type { OwnedBy } from "../api/generated/OwnedBy";
import { announce } from "../dom";
import { type MenuItem } from "../dialogs";
import { wording } from "../language/language";

/** The lorebook a card brings itself, as its editor asks for it: the card's first is named by the card alone. */
export const ownOf = (own: OwnedBy): LoreOf => ({ card: own.card_id, book: own.first ? undefined : own.reference });

/** The address of the lorebook `of`'s editor. */
export function lorebookAddress(of: LoreOf): string {
  if ("library" in of) return `#/library/lorebooks/${of.library}`;
  return `#/library/${of.card}/${of.book ? encodeURIComponent(of.book) : "lorebook"}`;
}

/**
 * Copy to library and Move to library of the card's own lorebook `own`, run by `act`. `changed` is told after
 * each and after its Undo, with the address of where the lorebook now is when it moved (the library's lorebook,
 * or the card's own again), else none.
 */
export function ownLines(own: OwnedBy, act: (action: () => Promise<void>) => Promise<boolean>, changed: (moved: string | null) => void | Promise<void>): MenuItem[] {
  const which = { reference: own.reference };
  const copy = () =>
    act(async () => {
      const made = await copyLorebook(own.card_id, which);
      announce(wording("lore-own-copied-to-the-library"), async () => {
        // The copy is no one's but the library's: it goes for good.
        await changeLorebook(made.id, { trashed: true });
        await deleteLorebook(made.id);
        await changed(null);
      });
      await changed(null);
    });
  const move = () =>
    act(async () => {
      const moved = await moveLorebook(own.card_id, which);
      // The editor gives way to the library's lorebook: the notice goes along (`carry`).
      announce(wording("lore-own-moved-to-the-library"), async () => {
        await moveBack(own.card_id, moved.id);
        // Put back, it is the card's last: its reference names it.
        await changed(lorebookAddress({ card: own.card_id, book: own.reference }));
      }, true);
      await changed(lorebookAddress({ library: moved.id }));
    });
  return [
    { label: wording("card-box-copy-to-library"), shape: "copy", sub: wording("lore-own-a-separate-lorebook-to"), action: () => void copy() },
    { label: wording("lore-own-move-to-library"), shape: "library", sub: wording("lore-own-one-lorebook-in-the"), action: () => void move() },
  ];
}
