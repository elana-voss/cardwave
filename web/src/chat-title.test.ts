import { expect, test } from "vitest";
import { chatNames } from "./chat-title";

const at = (day: number, hour: number) => new Date(2020, 5, day, hour).getTime();
const chat = (title: string, updated_at: number, name = "Mira") => ({ names: [name], title, updated_at });

test("chats of one name say their day, and their time where two fall on one day; others stay as they are", () => {
  const told = chatNames([chat("", at(2, 9)), chat("", at(2, 20)), chat("", at(5, 9)), chat("", at(5, 9), "Bram")]);
  expect(told[3]).toBe("Bram");
  expect(told[0]).toMatch(/^Mira · .*09:00$/);
  expect(told[1]).toMatch(/^Mira · .*20:00$/);
  expect(told[2]).toMatch(/^Mira · 5 Jun/);
  expect(chatNames([chat("Sea", at(2, 9))])).toEqual(["Mira · Sea"]);
});
