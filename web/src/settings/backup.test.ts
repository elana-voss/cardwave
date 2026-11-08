// What backup.ts does without a browser: a backup always has a password, asked for where none is on; a backup made
// with a password is asked for it at the restore, and sent again with it.
import { beforeEach, expect, test, vi } from "vitest";
import { ApiError, restoreBackup, saveBackup } from "../api/client";
import { backupLine, restoreDialog } from "./backup";

vi.mock("../api/client", async (actual) => ({ ...(await actual<typeof import("../api/client")>()), restoreBackup: vi.fn(), saveBackup: vi.fn() }));

beforeEach(() => document.body.replaceChildren());

/** Waits for what the dialog does after a press. */
const settled = () => new Promise((done) => setTimeout(done, 0));

test("a backup that needs its password asks for it, and is sent again with it", async () => {
  vi.mocked(restoreBackup).mockRejectedValueOnce(new ApiError(401, "backup_password_needed")).mockResolvedValueOnce();
  const home = document.body.appendChild(document.createElement("section"));
  const box = restoreDialog(home);
  const file = new File(["Cardwave backup 1\n"], "cardwave-backup.cwbackup");
  const picker = box.querySelector<HTMLInputElement>("input[type=file]")!;
  Object.defineProperty(picker, "files", { value: [file] });
  picker.dispatchEvent(new Event("change"));
  const password = box.querySelector<HTMLInputElement>("input[type=password]")!;
  expect(password.closest<HTMLElement>(".fld")!.hidden).toBe(true);

  box.querySelector("form")!.requestSubmit();
  await settled();
  expect(restoreBackup).toHaveBeenLastCalledWith(file, undefined);
  expect(password.closest<HTMLElement>(".fld")!.hidden).toBe(false);
  expect(box.textContent).toContain("This backup needs its password.");

  password.value = "harbour lights";
  box.querySelector("form")!.requestSubmit();
  await settled();
  expect(restoreBackup).toHaveBeenLastCalledWith(file, "harbour lights");
});

/** The line "Backup", shown as a password being on or not, in the page. */
function backUp(on: boolean): HTMLElement {
  document.body.append(Object.assign(document.createElement("div"), { id: "toast" }));
  const home = document.body.appendChild(document.createElement("section"));
  const line = backupLine(() => home);
  line.show(on);
  home.append(...line.nodes);
  [...home.querySelectorAll("button")].find((button) => button.textContent === "Save backup")!.click();
  return home;
}

test("where no password is on, Back up asks for one, twice alike, and the backup is sealed by it", async () => {
  vi.mocked(saveBackup).mockClear();
  const home = backUp(false);
  const box = home.querySelector("dialog")!;
  expect(box.textContent).toContain("Back up with a password");
  box.querySelector<HTMLInputElement>("#backup-new")!.value = "harbour lights";
  box.querySelector<HTMLInputElement>("#backup-repeat")!.value = "harbor lights";
  box.querySelector("form")!.requestSubmit();
  await settled();
  expect(box.textContent).toContain("The two passwords differ.");
  expect(saveBackup).not.toHaveBeenCalled();

  box.querySelector<HTMLInputElement>("#backup-repeat")!.value = "harbour lights";
  box.querySelector("form")!.requestSubmit();
  await settled();
  expect(saveBackup).toHaveBeenCalledWith("harbour lights", expect.any(Function));
  expect(box.open).toBe(false);
});

test("where a password is on, Back up saves at once, sealed by it", () => {
  vi.mocked(saveBackup).mockClear();
  const home = backUp(true);
  expect(home.querySelector("dialog")).toBeNull();
  expect(saveBackup).toHaveBeenCalledWith(undefined, expect.any(Function));
});

test("Back up waits until it is known whether a password is on", () => {
  const line = backupLine(() => document.body);
  const button = line.nodes[0].querySelector("button")!;
  expect(button.disabled).toBe(true);
  line.show(false);
  expect(button.disabled).toBe(false);
});
