// What a chat opened draws attached: the server's waiting attachments with what the user attached meanwhile; what
// the field keeps once its message is sent.
import { expect, test } from "vitest";
import { afterSending, withWaiting } from "./composer";

test("what waits attached is kept beside what was attached before it came, each once", () => {
  const one = { id: 1, name: "cats.txt", picture: false };
  const two = { id: 2, name: "dogs.png", picture: true };
  expect(withWaiting([two], [one, two])).toEqual([one, two]);
  expect(withWaiting([], [one])).toEqual([one]);
});

test("words typed while the message was being sent stay in the field once it is sent", () => {
  expect(afterSending("Hello", "Hello")).toBe("");
  expect(afterSending("Hello and more", "Hello")).toBe("and more");
  expect(afterSending("Hello\nmore", "Hello")).toBe("more");
  // Changed meanwhile, the field is left as the user made it.
  expect(afterSending("Hi there", "Hello")).toBe("Hi there");
});
