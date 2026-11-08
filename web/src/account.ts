// The account the page acts for: what it is called, asked of the server once and kept while the app runs, for
// all that shows it (the rail, the account's page, a chat's round, a new card's creator).
//
// `account` answers it, asking the server the first time and again only after an asking that failed; `take`
// is given the account as it is after a change, by the page that renamed it (`rename`) and by the server's
// word of a change made elsewhere (the event `account`, which main.ts hands on), and tells who watches;
// `watchAccount` is told the account as soon as it is known and whenever it changes, until what it answers
// with is called (a screen's `View.left`). An answer that was on its way when a change came is the older of
// the two and is dropped. `reread` asks the server anew, which main.ts does when the page hears the server
// again after a drop: a rename made meanwhile was not told, and an asking at the start may have failed.
// `showRound` puts the account's picture, or its letter, into a round; `elsewhere` is whether the page is of
// another device, which main.ts says at the start.
import { getAccount, renameAccount } from "./api/client";
import type { Account } from "./api/generated/Account";
import { el } from "./dom";
import { initialOf } from "./format";

/** Whether the page is of another device, signed in by the home network. */
export let elsewhere = false;
export const setElsewhere = (now: boolean) => void (elsewhere = now);

/** Puts the account's picture into `round`, or the first letter of its name where it has none. */
export function showRound(round: HTMLElement, { name, picture }: Pick<Account, "name" | "picture">): void {
  round.replaceChildren(picture ? el("img", { src: picture, alt: "" }) : initialOf(name));
}

/** The account, once the server has said or a change was taken. */
let current: Account | undefined;
/** The asking that is on its way. */
let asking: Promise<void> | undefined;
const watching = new Set<(account: Account) => void>();

/** Takes the account as it is now, and tells who watches. */
export function take(account: Account): void {
  current = account;
  for (const tell of watching) tell(account);
}

/** The account the page acts for. It is asked for once; an asking that failed is not kept, so the next one asks again. */
export async function account(): Promise<Account> {
  if (!current) {
    asking ??= getAccount()
      .then((told) => {
        // An account taken meanwhile is the newer one.
        if (!current) take(told);
      })
      .finally(() => (asking = undefined));
    await asking;
  }
  return current!;
}

/**
 * Has `tell` told the account: now if it is known, else once the server has said, and from then on whenever it
 * changes. Where the server does not say, nothing is told. Answers how the watching is ended, which a screen
 * does when it is left.
 */
export function watchAccount(tell: (account: Account) => void): () => void {
  watching.add(tell);
  if (current) tell(current);
  else void account().catch(() => {});
  return () => void watching.delete(tell);
}

/** Asks the server for the account anew and tells who watches. Where the server does not say, what is known stays. */
export const reread = (): Promise<void> => getAccount().then(take, () => {});

/** Gives the account another name. All that shows the name is told; a name the server refuses fails with its reason. */
export async function rename(name: string): Promise<Account> {
  const renamed = await renameAccount({ name });
  take(renamed);
  return renamed;
}
