// Account › Sharing's group "Other devices": the line "From anywhere" with a Tailscale address, and the hint on
// Tailscale without one (the server's network state a stand-in).
import { expect, test, vi } from "vitest";
import { getNetwork } from "../api/client";
import { wording } from "../language/language";
import { devicesGroup } from "./server";

vi.mock("../api/client", () => ({ getNetwork: vi.fn() }));

/** The group, once the server's `anywhere` is shown. */
async function shown(anywhere: string | null): Promise<HTMLElement> {
  vi.mocked(getNetwork).mockResolvedValue({ on: true, address: "http://192.168.1.20:8477/", anywhere });
  const group = devicesGroup(() => document.body);
  await new Promise((done) => setTimeout(done));
  return group;
}

const visible = (group: HTMLElement, words: string) =>
  [...group.querySelectorAll<HTMLElement>(".item, p")].some((node) => !node.hidden && node.textContent?.includes(words));

test("a Tailscale address is shown from anywhere, and without one how to get it", async () => {
  const far = await shown("http://100.101.102.103:8477/");
  expect(visible(far, "http://100.101.102.103:8477/")).toBe(true);
  expect(visible(far, wording("server-tailscale"))).toBe(false);

  const near = await shown(null);
  expect(visible(near, wording("server-anywhere"))).toBe(false);
  expect(visible(near, wording("server-tailscale"))).toBe(true);
  expect(near.querySelector<HTMLAnchorElement>("p a")?.href).toBe("https://tailscale.com/download");
});
