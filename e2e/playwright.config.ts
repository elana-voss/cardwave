import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "tests",
  // The run-throughs (9x-run-through-*) run only with RUN_THROUGHS=1: when asked, or as tools/check.sh's `run-throughs`;
  // the readme's screenshots (99-screenshots) only with SCREENSHOTS=1, never by tools/check.sh.
  testIgnore: [process.env.RUN_THROUGHS === "1" ? [] : [/run-through/], process.env.SCREENSHOTS === "1" ? [] : [/screenshots/]].flat(),
  // Spec files run beside each other, each on a server of its own (test.ts); a file's tests run one after the other.
  workers: 4,
  // Builds the UI and the server once, and cleans up after the run.
  globalSetup: "./server.mjs",
  use: { browserName: "chromium", headless: true },
  // A picture of a screen is compared exactly: Playwright's own threshold lets a small change of a colour pass.
  expect: { toHaveScreenshot: { threshold: 0, maxDiffPixels: 0 } },
});
