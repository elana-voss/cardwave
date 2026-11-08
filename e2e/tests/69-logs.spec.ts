import { expect, test } from "../test";

// The line "Logs" of About Cardwave: in a browser it says where the logs are and has no "Open folder", which
// only the desktop app can do.

test("About Cardwave says where the logs are", async ({ page }) => {
  await page.goto("/#/settings/about");
  const logs = page.locator(".item").filter({ has: page.getByText("Logs", { exact: true }) });
  await expect(logs).toContainText("What Cardwave did and any crashes, a file a day, kept 7 days: for help when something goes wrong · in the folder “logs” in Cardwave's data folder");
  await expect(logs.getByRole("button", { name: "Open folder" })).toHaveCount(0);
});
