// What a run of the browser tests keeps to itself (server.mjs), which no screen shows. It asks no server.
//
// Its one test is the test of `alone`.
import { alone } from "../server.mjs";
import { expect, test } from "../test";

test("a second run with this run's ports ends before it stops a server: the run holds a port while it lasts", async () => {
  // As a second run's setup would ask, first of all.
  await expect(alone()).rejects.toThrow("another run of the browser tests has the ports");
});
