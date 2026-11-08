// Why the microphone cannot be used, told per case in the app's words: never the browser's own text.
import { afterEach, expect, test, vi } from "vitest";
import { microphone } from "./microphone";
import { inDesktop } from "../desktop";

vi.mock("../desktop", () => ({ inDesktop: vi.fn(() => false) }));

const refusing = (name: string) =>
  Object.defineProperty(navigator, "mediaDevices", { configurable: true, value: { getUserMedia: vi.fn(async () => Promise.reject(new DOMException("Requested device not found", name))) } });

afterEach(() => {
  Object.defineProperty(navigator, "mediaDevices", { configurable: true, value: undefined });
});

test("each case has its own sentence, never the browser's words", async () => {
  refusing("NotFoundError");
  await expect(microphone()).rejects.toThrow("No microphone was found: plug one in, then try again.");
  refusing("NotAllowedError");
  await expect(microphone()).rejects.toThrow("This page may not use the microphone: allow it in the browser's settings for this site.");
  vi.mocked(inDesktop).mockReturnValue(true);
  await expect(microphone()).rejects.toThrow("Cardwave may not use the microphone: allow it in Windows' privacy settings, under Microphone.");
  refusing("NotReadableError");
  await expect(microphone()).rejects.toThrow("The microphone could not be started: close any other program that uses it, then try again.");
  // A page over plain http on another device has no microphone at all.
  Object.defineProperty(navigator, "mediaDevices", { configurable: true, value: undefined });
  await expect(microphone()).rejects.toThrow("The browser offers no microphone at this address: use one on the computer Cardwave runs on.");
});
