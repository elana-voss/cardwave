// What account.ts keeps of the account, without a browser: that it asks the server once, asks again after an
// asking that failed, tells who watches at first and after a rename, drops an answer that is older than
// what it was told meanwhile, and asks anew when it is told to. The module keeps the account while the app runs, so each test loads it anew
// (`load`).
import { beforeEach, expect, test, vi } from "vitest";
import { getAccount, renameAccount } from "./api/client";
import type { Account } from "./api/generated/Account";

vi.mock("./api/client", () => ({ getAccount: vi.fn(), renameAccount: vi.fn() }));

const LOCAL: Account = { name: "local", local: true, picture: null };
const ROWAN: Account = { name: "Rowan", local: true, picture: null };

/** The module as a start of the app has it: nothing known yet. */
async function load(): Promise<typeof import("./account")> {
  vi.resetModules();
  return import("./account");
}

beforeEach(() => {
  vi.mocked(getAccount).mockReset().mockResolvedValue(LOCAL);
  vi.mocked(renameAccount).mockReset();
});

test("the account is asked for once, however many ask, at once or later", async () => {
  const { account } = await load();
  expect(await Promise.all([account(), account()])).toEqual([LOCAL, LOCAL]);
  expect(await account()).toEqual(LOCAL);
  expect(getAccount).toHaveBeenCalledTimes(1);
});

test("an asking that failed is not kept: who asks gets the reason, and the next asking asks again", async () => {
  const { account } = await load();
  vi.mocked(getAccount).mockRejectedValueOnce(new Error("the server is away"));
  await expect(account()).rejects.toThrow("the server is away");
  expect(await account()).toEqual(LOCAL);
  expect(getAccount).toHaveBeenCalledTimes(2);
});

test("who watches is told the account once the server has said, at once when it is known, and after a rename, until it leaves", async () => {
  const { account, rename, take, watchAccount } = await load();
  const first = vi.fn();
  watchAccount(first);
  // Not before the server has said.
  expect(first).not.toHaveBeenCalled();
  await account();
  expect(first.mock.calls).toEqual([[LOCAL]]);
  // One that begins to watch later is told what is known, without another asking.
  const second = vi.fn();
  const left = watchAccount(second);
  expect(second.mock.calls).toEqual([[LOCAL]]);
  expect(getAccount).toHaveBeenCalledTimes(1);

  vi.mocked(renameAccount).mockResolvedValue(ROWAN);
  expect(await rename(" Rowan ")).toEqual(ROWAN);
  expect(renameAccount).toHaveBeenCalledWith({ name: " Rowan " });
  expect(first.mock.calls).toEqual([[LOCAL], [ROWAN]]);
  expect(second.mock.calls).toEqual([[LOCAL], [ROWAN]]);
  expect(await account()).toEqual(ROWAN);

  // One that has left is told no more.
  left();
  take({ name: "Wren", local: true, picture: null });
  expect(first).toHaveBeenCalledTimes(3);
  expect(second).toHaveBeenCalledTimes(2);
});

test("a name the server refuses changes nothing, and nobody is told", async () => {
  const { account, rename, watchAccount } = await load();
  await account();
  const watching = vi.fn();
  watchAccount(watching);
  vi.mocked(renameAccount).mockRejectedValue(new Error("the account needs a name"));
  await expect(rename("")).rejects.toThrow("the account needs a name");
  expect(watching).toHaveBeenCalledTimes(1);
  expect(await account()).toEqual(LOCAL);
});

test("where the server does not say, who watches is told nothing", async () => {
  const { watchAccount } = await load();
  vi.mocked(getAccount).mockRejectedValueOnce(new Error("the server is away"));
  const watching = vi.fn();
  watchAccount(watching);
  await new Promise((done) => setTimeout(done));
  expect(watching).not.toHaveBeenCalled();
});

test("read again, the account is asked for anew and who watches is told; where the server does not say, what is known stays", async () => {
  const { account, reread, watchAccount } = await load();
  const watching = vi.fn();
  watchAccount(watching);
  await account();
  vi.mocked(getAccount).mockResolvedValueOnce(ROWAN);
  await reread();
  expect(getAccount).toHaveBeenCalledTimes(2);
  expect(watching.mock.calls).toEqual([[LOCAL], [ROWAN]]);
  vi.mocked(getAccount).mockRejectedValueOnce(new Error("the server is away"));
  await reread();
  expect(watching).toHaveBeenCalledTimes(2);
  expect(await account()).toEqual(ROWAN);
  expect(getAccount).toHaveBeenCalledTimes(3);
});

test("an answer that was on its way when the account was renamed elsewhere is the older one, and is dropped", async () => {
  const { account, take, watchAccount } = await load();
  let answer = (_: Account) => {};
  vi.mocked(getAccount).mockReturnValueOnce(new Promise((done) => (answer = done)));
  const watching = vi.fn();
  watchAccount(watching);
  const asked = account();
  // The server's word of a rename comes before the answer to the asking.
  take(ROWAN);
  answer(LOCAL);
  expect(await asked).toEqual(ROWAN);
  expect(watching.mock.calls).toEqual([[ROWAN]]);
});
