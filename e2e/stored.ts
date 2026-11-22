// The chat model and the image model stored as first run's "Confirm" stores them (`confirm` in
// web/src/setup/models-step.ts), for a spec that prepares through `request`. Each answers the first refusal,
// else what the server shows of it (`PUT /api/provider`, `GET /api/images`), so a spec asks its `status()`.
// `setSettings` changes the settings and fails the spec itself, with the server's answer, where they are refused.
import { expect, type APIRequestContext, type APIResponse } from "@playwright/test";

/** Stores the chat model as first run's "Confirm" does (`PUT /api/provider`). */
export const setProvider = (request: APIRequestContext, stored: object): Promise<APIResponse> => request.put("/api/provider", { data: stored });

/** Picks the image model at the provider of its own address, added where there is none, else at the chat model's. */
export async function setImages(request: APIRequestContext, own: { model: string; base_url?: string; api_key?: string }): Promise<APIResponse> {
  let at: number;
  if (own.base_url !== undefined) {
    const added = await request.post("/api/provider-list", { data: { base_url: own.base_url, api_key: own.api_key } });
    if (!added.ok()) return added;
    at = (await added.json()).id;
  } else {
    const now = await (await request.get("/api/provider-list")).json();
    at = now.kinds.find((kind: { kind: string }) => kind.kind === "chat")?.provider_id;
  }
  const picked = await request.put("/api/kinds/images", { data: { provider_id: at, model: own.model } });
  return picked.ok() ? request.get("/api/images") : picked;
}

/** Changes the given settings (`PATCH /api/settings`); a refusal fails the spec with the server's answer. */
export async function setSettings(request: APIRequestContext, data: object): Promise<void> {
  const set = await request.patch("/api/settings", { data });
  expect(set.status(), await set.text()).toBe(200);
}
