// Who knows a memory in words, for Knowledge › Memories' rows and Search Cardwave's hits of a memory.
import type { Known } from "./api/generated/Known";
import { names } from "./format";
import { wording } from "./language/language";

/** Who knows a memory, as its row and its hit say it ("Known by Mira and you", "Known by nobody"). */
export function knownLine(known: Known): string {
  if (known.code === "everyone") return wording("memories-known-by-everyone");
  const all = known.you ? [...known.names, wording("memories-you")] : known.names;
  return all.length ? wording("memories-known-by-these", { names: names(all) }) : wording("memories-known-by-nobody");
}
