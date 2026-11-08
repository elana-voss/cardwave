// Which model each role of the coding team has.
import { expect, test } from "vitest";
import type { CodingTeam } from "../api/generated/CodingTeam";
import { roleModels } from "./coding-team";

const team: CodingTeam = {
  team: "balanced",
  planner_model: null,
  worker_model: null,
  auditor_model: null,
  workers: 7,
  audit: "never",
};

test("a role without its own model has the chat model, the workers the background model", () => {
  const provider = { model: "big", worker_model: "small" } as Parameters<typeof roleModels>[1];
  expect(roleModels(team, provider)).toEqual({ planner: "big", worker: "small", auditor: "big" });
  expect(roleModels({ ...team, auditor_model: "judge" }, { ...provider!, worker_model: null }).worker).toBe("big");
});
