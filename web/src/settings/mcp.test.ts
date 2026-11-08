// The address of Account › Server's group "Other programs".
import { expect, test } from "vitest";
import { mcpAddress } from "./mcp";

test("the MCP server's address is shown on a page opened on this computer", () => {
  const at = (href: string) => new URL(href);
  expect(mcpAddress(at("http://127.0.0.1:8477/#/account/server"))).toBe("http://127.0.0.1:8477/api/mcp");
  expect(mcpAddress(at("http://localhost:8478/"))).toBe("http://localhost:8478/api/mcp");
  // Opened by the home network's address, which the server does not answer MCP at.
  expect(mcpAddress(at("http://192.168.1.20:8477/"))).toBeNull();
});
