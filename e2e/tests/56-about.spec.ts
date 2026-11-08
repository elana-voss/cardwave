import { expect, test } from "../test";
import { NOW, picture, stopClock } from "../pictures";

// Settings › "About Cardwave": the settings' line with the version leads to the page, whose head says the version
// and the day the server was built; a model's and a list's "Licence" and a library's row open the panel with the
// texts; the libraries are searched by name; a voice under CC BY names whom its set asks for. The picture
// (`about`, 1440 px, light) is of the page answered with three libraries by `page.route`, and the day it was
// built with `NOW`, as the real list changes with every library updated and the day with every build.

test("the settings' line leads to the page, whose panel shows each license's text", async ({ page, request }) => {
  const status = await (await request.get("/api/status")).json();
  const all = await (await request.get("/licenses.json")).json();
  await page.goto("/#/settings");
  const link = page.getByRole("link", { name: /About Cardwave/ });
  await expect(link).toContainText(`Version ${status.version} · licences`);
  await link.click();
  await expect(page).toHaveURL(/#\/settings\/about$/);
  await expect(page.locator(".about-head")).toContainText(new RegExp(`^CardwaveVersion ${status.version.replaceAll(".", "\\.")} · .+\\d{4}`));

  // "Logs" stands under the head, before What's new, which points to it.
  await expect(page.locator(".page-col > :nth-child(2)")).toContainText("Logs");
  await expect(page.locator(".page-col > :last-child")).toContainText("Provider and model list");

  const models = page.locator(".settings-group", { has: page.getByRole("heading", { name: "Models" }) });
  await expect(models.locator(".item").first()).toContainText("bge-m3Search model · MIT · by BAAI");
  await expect(models.locator(".item")).toHaveCount(4);
  // The companion's figure and Mixamo's animations have a group of their own.
  const figures = page.locator(".settings-group", { has: page.getByRole("heading", { name: "Figures and animations" }) });
  await expect(figures.locator(".item")).toHaveText([/^RobotExpressiveThe companion's robot · CC0/, /^MixamoAnimations of the companion's woman and man · Adobe's terms · by Adobe/]);
  await models.getByRole("button", { name: "Licence of bge-m3" }).click();
  const panel = page.getByRole("dialog", { name: "bge-m3" });
  await expect(panel.locator("pre")).toContainText("Copyright (c) 2022 staoxiao");
  await panel.getByRole("button", { name: "Close" }).click();
  await expect(panel).toHaveCount(0);

  const voices = page.locator(".settings-group", { has: page.getByRole("heading", { name: "Voices" }) });
  await expect(voices.locator(".item", { hasText: "Anna" })).toContainText("VCTK · CC BY 4.0 · Speaker p228 of the CSTR VCTK Corpus");
  await expect(voices.locator(".item", { hasText: "Marius" }).locator(".meta")).toHaveText("Voice donations · CC0");

  const libraries = page.locator(".settings-group", { has: page.getByRole("heading", { name: "Open-source software" }) });
  await expect(libraries.locator(".group-head")).toContainText(`${all.libraries.length} packages`);
  await expect(libraries.locator(".item")).toHaveCount(all.libraries.length);
  await libraries.getByPlaceholder("Find a package").fill("AXUM");
  await expect(libraries.locator(".item-label")).toHaveText(["axum", "axum-core", "axum-extra"]);
  await libraries.getByRole("button", { name: "axum", exact: true }).click();
  await expect(page.getByRole("dialog", { name: "axum" }).locator("pre")).toContainText("Permission is hereby granted");
  await page.keyboard.press("Escape");
  await libraries.getByPlaceholder("Find a package").fill("no such thing");
  await expect(libraries.locator(".item")).toHaveText(["No package by that name."]);

  const lists = page.locator(".settings-group", { has: page.getByRole("heading", { name: "Provider and model list" }) });
  await lists.getByRole("button", { name: "Licence of models.dev" }).click();
  await expect(page.getByRole("dialog", { name: "models.dev" }).locator("pre")).toContainText("Copyright (c) 2025 models.dev");
});

test.describe("at 1440 px, light", () => {
  test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
  test.beforeEach(({ page }) => stopClock(page));

  test("About Cardwave: the models, the voices and three libraries", async ({ page }) => {
    await page.route("**/api/status", async (route) => route.fulfill({ json: { ...(await (await route.fetch()).json()), version: "0.1.0", built: NOW.getTime() } }));
    await page.route("**/licenses.json", async (route) => {
      const all = await (await route.fetch()).json();
      const libraries = [
        { name: "axum", version: "0.8.4", license: "MIT", texts: [0] },
        { name: "image", version: "0.25.6", license: "MIT OR Apache-2.0", texts: [0] },
        { name: "three", version: "0.170.0", license: "MIT", texts: [0] },
      ];
      route.fulfill({ json: { ...all, libraries } });
    });
    // Two versions, so that the picture stays as the file grows.
    await page.route("**/whats-new.md", (route) =>
      route.fulfill({ contentType: "text/markdown", body: "# 0.2.0\n\nBetter voices.\n\n- Faster replies.\n- A new theme.\n\n# 0.1.0\n\nThe new Cardwave.\n" }),
    );
    await page.goto("/#/settings/about");
    await expect(page.getByRole("heading", { name: "Provider and model list" })).toBeVisible();
    await expect(page.getByText("Version 0.2.0")).toBeVisible();
    await picture(page, "about-1440-light");
  });
});
