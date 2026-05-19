/// Per-entry transform used both by `CharacterCardV3._tagsFromJson` and by
/// the card-edit tools when proposing changes to the `tag` list. Keeping
/// it in one place ensures the diff the user sees in the approval dialog
/// matches what will actually be stored after the next deserialize round-trip.
String normalizeTagEntry(String raw) => raw.trim().toLowerCase();
