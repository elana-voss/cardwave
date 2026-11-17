import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "tests",
  // The run-throughs (9x-run-through-*) run only with RUN_THROUGHS=1: when asked, or as tools/check.sh's `run-throughs`;
  // the readme's screenshots (99-screenshots) only with SCREENSHOTS=1, never by tools/check.sh.
  testIgnore: [process.env.RUN_THROUGHS === "1" ? [] : [/run-through/], process.env.SCREENSHOTS === "1" ? [] : [/screenshots/]].flat(),
  // Spec files run beside each other, each on a server of its own (test.ts); a file's tests run one after the other.
  workers: 6,
  // Builds the UI and the server once, and cleans up after the run.
  globalSetup: "./server.mjs",
  // WEBKIT=1: Playwright's own WebKit, the stand-in for Linux's window (WebKitGTK; run in WSL, 154), where the stored
  // pictures are not compared: they are Windows' Chromium's, and a picture differs by machine.
  use: { browserName: process.env.WEBKIT === "1" ? "webkit" : "chromium", headless: true },
  ignoreSnapshots: process.env.WEBKIT === "1",
  // A picture of a screen is compared exactly: Playwright's own threshold lets a small change of a colour pass.
  expect: { toHaveScreenshot: { threshold: 0, maxDiffPixels: 0 } },
});
