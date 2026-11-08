// The view Posters' 14 designs, two per mood: what each lays out where and which fonts it waits for; how it looks is
// the class poster-<mood>-<letter> in ../app/posters.css. The table is that of the page "Cardwave Posters"
// (docs/design.md), which names the moods thriller and scifi: here the server's words, horror and sci_fi.
import type { Mood } from "../api/generated/Mood";
import type { Poster } from "../api/generated/Poster";

/** Which of a mood's two designs a card has; stored with it by the server, never changing. */
export type Letter = "a" | "b";
/** A design's name, also the end of its class. */
export type DesignName = `${Mood}-${Letter}`;
/** What stands at an end of a poster. */
export type Part = "title" | "tagline";

export interface Design {
  /** What stands at the top and at the foot, in order. Where the title is, is its home end. */
  top: Part[];
  foot: Part[];
  /** The largest title, as a share of the poster's width. */
  largest: number;
  /** How much of the zone's width the title may take. */
  span: number;
  /** The fonts, as `document.fonts.load` asks for them. */
  fonts: string[];
  /** The title's hue at full strength. */
  vivid?: boolean;
  /** The picture's warm hues first. */
  warm?: boolean;
  /** Text to the left, not centred. */
  left?: boolean;
  /** Letter spacing that narrows as the title grows (`--tr`). */
  track?: boolean;
  /** A leading "The", "A" or "An" set small above the title. */
  article?: boolean;
}

export const DESIGNS: Record<DesignName, Design> = {
  "horror-a": { top: ["tagline"], foot: ["title"], largest: 0.36, span: 0.94, vivid: true, fonts: ['40px "Anton"'] },
  "horror-b": { top: ["title", "tagline"], foot: [], largest: 0.14, span: 0.86, fonts: ['700 40px "Cinzel"', '500 40px "Cinzel"'] },
  "drama-a": { top: ["title", "tagline"], foot: [], largest: 0.17, span: 0.86, fonts: ['600 40px "Cormorant Garamond"', 'italic 500 40px "Cormorant Garamond"'] },
  "drama-b": { top: ["title", "tagline"], foot: [], largest: 0.24, span: 0.7, left: true, fonts: ['600 40px "Oswald"', '400 40px "Oswald"'] },
  "romance-a": { top: [], foot: ["title", "tagline"], largest: 0.3, span: 0.9, vivid: true, fonts: ['700 40px "Dancing Script"', '600 40px "Dancing Script"'] },
  "romance-b": { top: ["title", "tagline"], foot: [], largest: 0.24, span: 0.86, vivid: true, fonts: ['800 40px "Playfair Display"', 'italic 400 40px "Playfair Display"'] },
  "action-a": { top: [], foot: ["tagline", "title"], largest: 0.26, span: 0.92, vivid: true, left: true, fonts: ['40px "Archivo Black"'] },
  "action-b": { top: ["tagline"], foot: ["title"], largest: 0.2, span: 0.94, fonts: ['800 expanded 40px "Archivo"', '600 semi-expanded 40px "Archivo"'] },
  "sci_fi-a": { top: ["tagline"], foot: ["title"], largest: 0.13, span: 0.94, track: true, fonts: ['400 40px "Exo 2"', '500 40px "Exo 2"'] },
  "sci_fi-b": { top: [], foot: ["tagline", "title"], largest: 0.2, span: 0.9, vivid: true, left: true, fonts: ['800 40px "Orbitron"', '500 40px "Orbitron"'] },
  "comedy-a": { top: ["title", "tagline"], foot: [], largest: 0.26, span: 0.86, vivid: true, fonts: ['700 40px "Fredoka"', '500 40px "Fredoka"'] },
  "comedy-b": { top: [], foot: ["tagline", "title"], largest: 0.3, span: 0.88, vivid: true, fonts: ['40px "Lilita One"'] },
  "fantasy-a": { top: ["tagline"], foot: ["title"], largest: 0.2, span: 0.9, article: true, warm: true, fonts: ['40px "Marcellus SC"'] },
  "fantasy-b": { top: [], foot: ["tagline", "title"], largest: 0.3, span: 0.92, vivid: true, warm: true, fonts: ['40px "Kaushan Script"'] },
};

/** The design a card shows; none, for Gallery's plain tile, while it lacks a tagline, a mood or a letter. */
export function designOf(card: Poster | null): DesignName | null {
  return card?.tagline && card.mood && card.design ? `${card.mood}-${card.design}` : null;
}
