// What accounts.ts does without a browser: the menu "Switch account", and the sign-in screen's way to an account.
import { beforeEach, expect, test, vi } from "vitest";
import { setElsewhere } from "../account";
import { signInScreen, switchItems, watchAccounts } from "./accounts";
import { listAccounts, signIn } from "../api/client";
import type { AccountLine } from "../api/generated/AccountLine";

vi.mock("../api/client", async (actual) => ({ ...(await actual<typeof import("../api/client")>()), signIn: vi.fn(), listAccounts: vi.fn(() => new Promise(() => {})) }));

const OWNER: AccountLine = { id: 1, name: "local", local: true, current: true, password: false };
const ADA: AccountLine = { id: 2, name: "Ada", local: false, current: false, password: true };

/** Waits for what the screen does after a press. */
const settled = () => new Promise((done) => setTimeout(done, 0));

beforeEach(() => {
  document.body.replaceChildren();
  vi.mocked(signIn).mockReset().mockResolvedValue();
  vi.spyOn(location, "replace").mockImplementation(() => {});
  setElsewhere(false);
});

test("the menu lists the accounts, the one signed in chosen; this computer's account adds one, another device signs out", () => {
  const owner = switchItems([OWNER, ADA], true);
  expect(owner.map(({ label, chosen, group }) => [label, chosen, group])).toEqual([
    ["local", true, "Switch account"],
    ["Ada", false, undefined],
    ["Add account", undefined, undefined],
  ]);
  setElsewhere(true);
  expect(switchItems([{ ...OWNER, current: false }, { ...ADA, current: true }], false).map(({ label }) => label)).toEqual(["local", "Ada", "Sign out"]);
});

test("the sign-in screen offers the accounts: one with a password asks for it, one without signs in at once", async () => {
  const screen = document.body.appendChild(signInScreen([OWNER, ADA]));
  expect(screen.querySelector("h1")!.textContent).toBe("Choose your account");
  const choices = () => [...screen.querySelectorAll<HTMLButtonElement>(".account-choice")];
  expect(choices().map((line) => line.textContent)).toEqual(["LlocalThis computer’s account", "AAda"]);

  choices()[1].click();
  expect(screen.querySelector("h1")!.textContent).toBe("Ada");
  // The account picked is signed in to with "Sign in", and "Back" over it leads to the accounts.
  expect(screen.querySelector("button[type=submit]")!.textContent).toBe("Sign in");
  expect(screen.querySelector(".start-column > button")!.textContent).toBe("Back");
  screen.querySelector<HTMLInputElement>("input[type=password]")!.value = "tide pool";
  screen.querySelector("form")!.requestSubmit();
  await settled();
  expect(signIn).toHaveBeenLastCalledWith(2, "tide pool");
  expect(location.replace).toHaveBeenCalled();

  [...screen.querySelectorAll("button")].find((button) => button.textContent === "Back")!.click();
  choices()[0].click();
  await settled();
  expect(signIn).toHaveBeenLastCalledWith(1);
});

test("a lone account is asked for its password at once, and with none the screen says how one is made", () => {
  const lone = signInScreen([ADA]);
  expect([lone.querySelector("h1")!.textContent, lone.textContent?.includes("Back")]).toEqual(["Ada", false]);
  expect(signInScreen([]).querySelector("h1")!.textContent).toBe("No account to sign in to");
});

test("a sign-in that fails says why, with Try again, in place of a blank screen", async () => {
  vi.mocked(signIn).mockRejectedValueOnce(new Error("the server is not there"));
  const screen = signInScreen([OWNER]);
  await settled();
  expect(screen.textContent).toContain("The server is not there");
  [...screen.querySelectorAll("button")].find((button) => button.textContent === "Try again")!.click();
  await settled();
  expect(signIn).toHaveBeenCalledTimes(2);
  expect(location.replace).toHaveBeenCalled();
});

test("where the accounts could not be read, the next who watches asks again", async () => {
  vi.mocked(listAccounts).mockRejectedValueOnce(new Error("down")).mockResolvedValueOnce([OWNER, ADA]);
  const first = vi.fn();
  watchAccounts(first);
  await settled();
  expect(first).not.toHaveBeenCalled();
  const second = vi.fn();
  watchAccounts(second);
  await settled();
  expect(second).toHaveBeenCalledWith([OWNER, ADA]);
});
