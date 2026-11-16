// What personas.ts decides alone: a new persona whose picture failed is not made twice by the second Save.
import { expect, test, vi } from "vitest";
import { changePersona, createPersona, setPersonaPicture } from "../api/client";
import { useLanguage } from "../language/language";
import { personasView } from "./personas";

vi.mock("../api/client", () => ({
  listPersonas: vi.fn(async () => []),
  libraryLorebooks: vi.fn(async () => []),
  createPersona: vi.fn(async (persona: { name: string }) => ({ id: 7, name: persona.name })),
  changePersona: vi.fn(async () => undefined),
  setPersonaPicture: vi.fn(),
}));
vi.mock("../art", () => ({ PICTURES: ["image/png"], smallPicture: vi.fn(async (file: File) => file) }));

test("a new persona whose picture was refused is not made again by Save", async () => {
  useLanguage("en");
  Object.assign(URL, { createObjectURL: () => "blob:x", revokeObjectURL: () => undefined });
  vi.mocked(setPersonaPicture).mockRejectedValueOnce(new Error("refused")).mockResolvedValue(undefined as never);
  const view = personasView();
  document.body.replaceChildren(view.node);
  view.create!();
  const form = await vi.waitFor(() => view.node.querySelector("form")!);
  (form.querySelector("#persona-name") as HTMLInputElement).value = "Mira";
  const picker = form.querySelector("input[type=file]") as HTMLInputElement;
  Object.defineProperty(picker, "files", { value: [new File(["a"], "a.png", { type: "image/png" })] });
  picker.dispatchEvent(new Event("change"));
  form.requestSubmit();
  await vi.waitFor(() => expect(setPersonaPicture).toHaveBeenCalledTimes(1));
  await new Promise((done) => setTimeout(done, 20));
  form.requestSubmit();
  await vi.waitFor(() => expect(setPersonaPicture).toHaveBeenCalledTimes(2));
  expect(createPersona).toHaveBeenCalledTimes(1);
  expect(changePersona).toHaveBeenCalledTimes(1);
});
