// A card's content level in words, as its page's chips and the library's list say it: the server's terms
// ("sfw" and the like) stand among a described card's tags.

import { wording } from "../language/language";

/** A tag in words: a content level as the card's page says it, any other tag as it is. */
export function tagWord(tag: string): string {
  // A Map, as an object's own names ("constructor") would answer a tag.
  const levels = new Map([
    ["sfw", wording("character-rating-sfw")],
    ["suggestive", wording("character-rating-suggestive")],
    ["nsfw", wording("character-rating-nsfw")],
    ["nsfw-extreme", wording("character-rating-nsfw-extreme")],
  ]);
  return levels.get(tag) ?? tag;
}
