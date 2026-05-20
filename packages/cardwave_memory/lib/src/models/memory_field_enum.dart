/// The retrievable surfaces of a `StoryEvent`, used as the field key for both
/// the keyword index and the vector sidecar. [text] carries the dense
/// embedding (the contextual-prefixed event text); the rest are keyword-only
/// fields, with exact proper-noun hits on [characters] / [locations] boosted
/// at query time.
enum MemoryFieldEnum { text, characters, locations, items, concepts, keywords }
