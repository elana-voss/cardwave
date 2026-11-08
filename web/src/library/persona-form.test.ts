// The persona's form: its picture at the top, taken with "Save" as its name and description are.
import { expect, test, vi } from "vitest";
import type { Persona } from "../api/generated/Persona";
import { personaForm } from "./persona-form";

const WREN: Persona = { id: 1, name: "Wren", description: "", trashed: false, is_default: false, picture: "/api/personas/1/picture?at=5", lorebooks: [] };

const buttons = (node: HTMLElement) => [...node.querySelectorAll<HTMLButtonElement>(".persona-picture button")].filter((one) => !one.hidden).map((one) => one.textContent);

test("a persona without a picture has its initial and Add picture; one picked is saved with the form", async () => {
  const save = vi.fn(async () => true);
  const form = personaForm(save, () => {}, null, { ...WREN, picture: null });
  expect(form.node.querySelector(".persona-picture .initial")!.textContent).toBe("W");
  expect(buttons(form.node)).toEqual(["Add picture"]);
  const file = new File(["png"], "wren.png", { type: "image/png" });
  form.take(file);
  expect(buttons(form.node)).toEqual(["Remove", "Change"]);
  form.node.requestSubmit();
  await vi.waitFor(() => expect(save).toHaveBeenCalledWith("Wren", "", file, undefined));
});

test("a persona's picture is shown, Remove takes it away with Save, and nothing touched saves it as it is", async () => {
  const save = vi.fn(async () => true);
  const form = personaForm(save, () => {}, null, WREN);
  expect(form.node.querySelector<HTMLImageElement>(".persona-picture img")!.getAttribute("src")).toBe(WREN.picture);
  form.node.requestSubmit();
  await vi.waitFor(() => expect(save).toHaveBeenLastCalledWith("Wren", "", undefined, undefined));
  [...form.node.querySelectorAll<HTMLButtonElement>(".persona-picture button")].find((one) => one.textContent === "Remove")!.click();
  expect(buttons(form.node)).toEqual(["Add picture"]);
  form.node.requestSubmit();
  await vi.waitFor(() => expect(save).toHaveBeenLastCalledWith("Wren", "", null, undefined));
});

test("a persona's lorebooks are taken away with ×, added with +, and kept with Save", async () => {
  const save = vi.fn(async () => true);
  const book = (id: number, name: string) => ({ id, name, description: "", entries: 1, entry_names: [], favorite: false, archived: false, trashed: false, everywhere: false, used_by: [], chats: 0 });
  const form = personaForm(save, () => {}, Promise.resolve([book(1, "Map"), book(2, "Diary")]), { ...WREN, lorebooks: [{ id: 1, name: "Map", trashed: false }] });
  document.body.append(form.node);
  const lines = () => [...form.node.querySelectorAll(".persona-lorebooks li")].map((line) => line.firstChild!.textContent);
  const offered = () => [...form.node.querySelectorAll<HTMLElement>('.persona-lorebooks [role="menuitem"]')];
  await vi.waitFor(() => expect(offered().map((line) => line.textContent)).toEqual(["Diary"]));
  expect(lines()).toEqual(["Map"]);
  [...form.node.querySelectorAll<HTMLButtonElement>(".persona-lorebooks li button")].find((one) => one.ariaLabel === "Remove Map from this persona")!.click();
  offered().find((line) => line.textContent === "Diary")!.click();
  expect(lines()).toEqual(["Diary"]);
  form.node.requestSubmit();
  await vi.waitFor(() => expect(save).toHaveBeenLastCalledWith("Wren", "", undefined, [2]));
  // Put back as they were, they are not sent: what another window gave the persona meanwhile stays.
  [...form.node.querySelectorAll<HTMLButtonElement>(".persona-lorebooks li button")].find((one) => one.ariaLabel === "Remove Diary from this persona")!.click();
  offered().find((line) => line.textContent === "Map")!.click();
  form.node.requestSubmit();
  await vi.waitFor(() => expect(save).toHaveBeenLastCalledWith("Wren", "", undefined, undefined));
  form.node.remove();
});
