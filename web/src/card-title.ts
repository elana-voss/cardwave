// What a card is called where it is shown: its title, or the page's word where it names nothing.
import { wording } from "./language/language";

/** A card's title as the page shows it: the server sends none for a card that names nothing. */
export const cardTitle = (title: string) => title || wording("card-untitled");
