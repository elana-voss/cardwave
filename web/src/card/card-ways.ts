// The other ways a new character is made, offered over the empty card page (`#/library/new`) until its card is
// made: the character generator and "Make a character together", each a line with what it does. Writing it is the
// page under them. The page hides the group once the card is made (its title's first letter).
import { el, group, link } from "../dom";
import { wording } from "../language/language";

/** The group "Or let the AI help", its two lines leading to the generator and the interview. */
export const otherWays = (): HTMLElement =>
  el(
    "div",
    { className: "page-wide card-ways" },
    group(
      wording("card-new-help"),
      null,
      el("div", { className: "group" }, link("#/generator", wording("create-from-picks"), wording("card-new-generate-sub")), link("#/interview", wording("create-together"), wording("card-new-together-sub"))),
    ),
  );
