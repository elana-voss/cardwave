// The account's profile: who the account is, and what it is called, which is changed here.
//
// At `#/account/profile`, the first of the account's tabs (`accountTabs` of ../shell/account-tabs.ts). On top the account's
// letter in a round with its name and, where there are other accounts, what it is (`.profile-head`), under it the group "Account" with the line
// "Name": "Change" puts a field in the name's place, with "Save" and "Cancel" (`.item.renaming`), Enter saves
// and Escape cancels, and why a name was not taken stands in red under the line (`.item-wrong`). The name is
// account.ts's, which tells the rail of a new one. Under it the line "Picture": "Change" asks for a PNG, JPEG or
// WebP file, which is sent made at most `SIDE` pixels on its longer side (the server makes it smaller still and
// square), and "Remove" goes back to the letter. Then the line "Password" (password.ts): of this computer's
// account the setting that Settings › Data calls "Passphrase", of another its own password.
import { wording } from "../language/language";
import { account, rename, showRound, take, watchAccount } from "../account";
import { NAME_LIMIT } from "../settings/accounts";
import { getLock, listAccounts, setPicture } from "../api/client";
import type { Account } from "../api/generated/Account";
import { announce, atMost, el, failure, fileField, group, item, noticeBox, oneAtATime, reason, type View } from "../dom";
import { PICTURES, smallPicture } from "../art";
import { initialOf } from "../format";
import { passwordLine } from "../settings/password";
import { accountTabs } from "../shell/account-tabs";
import { LABELS } from "../setting-labels";

/** The line "Picture": the letter until a picture is taken, "Change" and, with a picture, "Remove". */
function pictureLine() {
  const says = el("span", { className: "meta" });
  const wrong = el("div", { className: "item-wrong" });
  const picturing = oneAtATime(wrong);
  const change = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("profile-change-picture"), disabled: true }, wording("profile-change"));
  const remove = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("profile-remove-picture"), hidden: true }, wording("profile-remove"));
  const picker = fileField(change, PICTURES.join(","), false, ([file]) => {
    if (file)
      void picturing(async () => {
        take(await setPicture(await smallPicture(file)));
        announce(wording("profile-picture-changed"));
      });
  });
  change.onclick = () => picker.click();
  remove.onclick = () =>
    void picturing(async () => {
      take(await setPicture(null));
      announce(wording("profile-picture-removed"));
    });
  return {
    node: el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, LABELS.profile.picture), says), remove, change, picker, wrong),
    /** Shows the account's picture, or its letter; it can be changed once the account is known. */
    show({ name, picture }: Account): void {
      says.textContent = picture ? wording("profile-your-picture") : wording("profile-no-picture", { letter: initialOf(name) });
      remove.hidden = !picture;
      change.disabled = false;
    },
  };
}

export function profileView(): View {
  const initial = el("span", { className: "initial initial-lg", ariaHidden: "true" });
  const called = el("span", { className: "profile-name fs-title semi" });
  // What kind of account it is, said only where there are others to tell it from.
  const kind = el("span", { className: "meta", hidden: true });
  const notice = noticeBox();

  // The line "Name": what the account is called, and "Change".
  const says = el("span", { className: "meta" });
  const change = el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("profile-change-name"), disabled: true }, wording("profile-change"));
  const line = item(LABELS.profile.name, says, change);

  // While it is changed, the line is a form: the field in the name's place, with "Save" and "Cancel".
  const field = el("input", { className: "field", id: "account-name", name: "name", required: true, autocomplete: "off" });
  atMost(field, NAME_LIMIT);
  const save = el("button", { type: "submit", className: "btn btn-primary" }, wording("common-save"));
  const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
  const wrong = el("div", { className: "item-wrong" });
  const form = el("form", { className: "item renaming", hidden: true }, el("div", { className: "item-text" }, el("label", { className: "item-label", htmlFor: field.id }, LABELS.profile.name), field), save, cancel, wrong);
  // One rename at a time; why one failed stands under the line.
  const saving = oneAtATime(wrong);

  /** Shows the line as it stands, or as the form that changes the name. */
  function changing(now: boolean): void {
    line.hidden = now;
    form.hidden = !now;
    // What failed before is of the try before.
    wrong.replaceChildren();
  }

  const picture = pictureLine();

  /** Shows the account: on top, and in the lines. */
  function show(now: Account): void {
    const { name, local } = now;
    showRound(initial, now);
    called.textContent = says.textContent = name;
    kind.textContent = local ? wording("profile-this-computer") : wording("profile-on-server");
    picture.show(now);
    change.disabled = false;
    // It is told now, whatever an asking before came to.
    notice.replaceChildren();
  }

  change.onclick = () => {
    field.value = says.textContent ?? "";
    changing(true);
    field.focus();
    field.select();
  };
  const leave = () => {
    changing(false);
    change.focus();
  };
  cancel.onclick = leave;
  form.onkeydown = (event) => {
    if (event.key !== "Escape" || event.isComposing) return;
    event.preventDefault();
    leave();
  };
  form.onsubmit = (event) => {
    event.preventDefault();
    void saving(async () => {
      await rename(field.value);
      leave();
    });
  };

  const password = passwordLine(LABELS.profile.password, () => node);
  const tabs = accountTabs("#/account/profile");
  const node: HTMLElement = el(
    "section",
    { className: "main g-28" },
    tabs.node,
    el(
      "div",
      { className: "page-col" },
      el("div", { className: "profile-head flex ai-c g-16" }, initial, el("div", { className: "flex f-col" }, called, kind)),
      group(wording("profile-account"), null, notice, el("div", { className: "group" }, line, form, picture.node, password.node)),
    ),
  );
  // Of this computer's account the password is the database's, which may be off; another's is its own, always on.
  // Where the accounts are not known the kind is said, as it is true either way.
  listAccounts()
    .then((all) => (kind.hidden = all.length < 2))
    .catch(() => (kind.hidden = false));
  Promise.all([account(), getLock()])
    .then(([{ local }, { password: on }]) => password.show(on || !local, !local))
    .catch((error) => notice.append(failure(reason(error))));
  // The account as it is known, and as it is after a change, made here or elsewhere. Where the server does not
  // say, the page says why and the name cannot be changed, until it does say.
  const watching = watchAccount(show);
  account().catch((error) => notice.replaceChildren(failure(reason(error))));
  return {
    node: node,
    left: () => {
      watching();
      tabs.left();
    },
  };
}
