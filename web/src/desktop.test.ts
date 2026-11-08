// Which window the page is in: what the companion is told of comes only from the desktop app's own window.
import { afterEach, describe, expect, it } from "vitest";
import { appWindow, nameWindow } from "./desktop";
import { useLanguage, wording } from "./language/language";

describe("appWindow", () => {
  afterEach(() => delete window.cardwaveDesktop);

  it("is the desktop app's own window, not a browser's page nor its window of one page", () => {
    expect(appWindow()).toBe(false);
    window.cardwaveDesktop = { downloads: null, logs: "C:/logs", window: "main" };
    expect(appWindow()).toBe(true);
    window.cardwaveDesktop = { downloads: null, logs: "C:/logs", window: "page" };
    expect(appWindow()).toBe(false);
  });
});

describe("nameWindow", () => {
  afterEach(() => {
    useLanguage("en");
    delete window.__TAURI_INTERNALS__;
  });

  it("names the window in the page's language, and anew when the language changes", () => {
    const asked: unknown[] = [];
    window.__TAURI_INTERNALS__ = { invoke: (command, args) => Promise.resolve(void asked.push([command, args])) };
    nameWindow(() => wording("companion-window"));
    expect(document.title).toBe("Cardwave companion");
    useLanguage("xx", "companion-window = Begleiter\n");
    expect(document.title).toBe("Begleiter");
    expect(asked).toEqual([
      ["window_title", { title: "Cardwave companion" }],
      ["window_title", { title: "Begleiter" }],
    ]);
  });
});
