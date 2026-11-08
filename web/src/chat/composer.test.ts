// What a chat opened draws attached: the server's waiting attachments with what the user attached meanwhile.
import { expect, test } from "vitest";
import { withWaiting } from "./composer";

test("what waits attached is kept beside what was attached before it came, each once", () => {
  const one = { id: 1, name: "cats.txt", picture: false };
  const two = { id: 2, name: "dogs.png", picture: true };
  expect(withWaiting([two], [one, two])).toEqual([one, two]);
  expect(withWaiting([], [one])).toEqual([one]);
});
