import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/utils/tag_normalizer.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Reads the named scalar field off [card].
String readScalarField(CharacterCardV3 card, CardFieldScalar field) {
  switch (field) {
    case CardFieldScalar.name:
      return card.name;
    case CardFieldScalar.nickname:
      return card.nickname ?? '';
    case CardFieldScalar.description:
      return card.description;
    case CardFieldScalar.personality:
      return card.personality;
    case CardFieldScalar.scenario:
      return card.scenario;
    case CardFieldScalar.firstMes:
      return card.firstMes;
    case CardFieldScalar.mesExample:
      return card.mesExample;
    case CardFieldScalar.systemPrompt:
      return card.systemPrompt;
    case CardFieldScalar.postHistoryInstructions:
      return card.postHistoryInstructions;
    case CardFieldScalar.creatorNotes:
      return card.creatorNotes;
  }
}

/// Validation error for a proposed scalar write, or null when allowed. The
/// name must not be blank: a blank name leaves the card with no label in the
/// library grid. Guards the assistant tool write path only; the editor's own
/// field handling is separate.
String? cardScalarWriteError(CardFieldScalar field, String content) {
  if (field == CardFieldScalar.name && content.trim().isEmpty) {
    return 'name cannot be empty; provide a non-blank name.';
  }
  return null;
}

/// Returns the mutable list backing the named list field on [card].
/// Caller may read or mutate the list directly; the card holds the same
/// reference.
List<String> listFieldOf(CharacterCardV3 card, CardFieldList field) {
  switch (field) {
    case CardFieldList.alternateGreeting:
      return card.alternateGreetings;
    case CardFieldList.groupOnlyGreeting:
      return card.groupOnlyGreetings;
    case CardFieldList.tag:
      return card.tags;
  }
}

/// Mutates [card] in place to apply the given approved proposals. Order
/// is fixed (not the approval order) to keep results predictable when
/// proposals overlap:
///   1. Scalar sets — independent, any order.
///   2. List sets — applied at their original indices before any list
///      mutation, so indices stay valid.
///   3. List appends — applied in the order recorded; tag appends that
///      would duplicate an existing entry are skipped (the deserializer
///      dedups too, but skipping here keeps the in-memory state matching
///      what the user will see after the next reload). The contains-check
///      normalizes both the existing entries and the new value, so a
///      "Fantasy" append collapses against an existing "fantasy" even when
///      that existing entry is still mixed-case in memory (just typed in the
///      editor, not yet reloaded).
///   4. List deletes — deduplicated by (field, index), then applied in
///      descending index order so removing one entry doesn't shift the
///      index of a later removal.
///
/// Overlap between phases: if the user approves both `set(0, X)` and
/// `delete(0)` on the same list, the set lands at index 0 first, then
/// the delete removes that entry. Net effect: delete wins, and the
/// proposed new value is gone. This is the intuitive outcome when both
/// are approved — anyone who wanted to keep X should have denied the
/// delete.
void applyCardEditProposals(
  CharacterCardV3 card,
  Iterable<CardEditProposal> approved,
) {
  final scalarSets = <CardScalarSetProposal>[];
  final listSets = <CardListSetProposal>[];
  final appends = <CardListAppendProposal>[];
  final deleteKeys = <(CardFieldList, int)>{};

  for (final p in approved) {
    switch (p) {
      case CardScalarSetProposal():
        scalarSets.add(p);
      case CardListSetProposal():
        listSets.add(p);
      case CardListAppendProposal():
        appends.add(p);
      case CardListDeleteProposal():
        deleteKeys.add((p.field, p.index));
    }
  }

  for (final p in scalarSets) {
    _writeScalarField(card, p.field, p.newValue);
  }
  for (final p in listSets) {
    final list = listFieldOf(card, p.field);
    if (p.index >= 0 && p.index < list.length) {
      list[p.index] = p.newValue;
    }
  }
  for (final p in appends) {
    final list = listFieldOf(card, p.field);
    // The new tag value was normalized at propose time, but a tag typed in
    // the editor and not yet reloaded can still be mixed-case in memory, so
    // normalize both sides before the duplicate check.
    if (p.field == CardFieldList.tag &&
        list.map(normalizeTagEntry).contains(p.newValue)) {
      continue;
    }
    list.add(p.newValue);
  }

  final deletesByField = <CardFieldList, List<int>>{};
  for (final key in deleteKeys) {
    (deletesByField[key.$1] ??= []).add(key.$2);
  }
  for (final entry in deletesByField.entries) {
    final indices = entry.value..sort((a, b) => b.compareTo(a));
    final list = listFieldOf(card, entry.key);
    for (final index in indices) {
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
      }
    }
  }
}

/// Normalizes [value] for proposals targeting [field]. Tag entries are
/// trim+lowercased so the diff the user sees matches what will land on
/// disk after the next deserialize.
String normalizeFieldValue(CardFieldList field, String value) =>
    field == CardFieldList.tag ? normalizeTagEntry(value) : value;

void _writeScalarField(
  CharacterCardV3 card,
  CardFieldScalar field,
  String value,
) {
  switch (field) {
    case CardFieldScalar.name:
      card.name = value;
    case CardFieldScalar.nickname:
      // Blank (empty or whitespace-only) clears the nickname so display
      // falls back to the name; a non-empty whitespace nickname would
      // render as a blank speaker label in chat.
      card.nickname = value.trim().isEmpty ? null : value;
    case CardFieldScalar.description:
      card.description = value;
    case CardFieldScalar.personality:
      card.personality = value;
    case CardFieldScalar.scenario:
      card.scenario = value;
    case CardFieldScalar.firstMes:
      card.firstMes = value;
    case CardFieldScalar.mesExample:
      card.mesExample = value;
    case CardFieldScalar.systemPrompt:
      card.systemPrompt = value;
    case CardFieldScalar.postHistoryInstructions:
      card.postHistoryInstructions = value;
    case CardFieldScalar.creatorNotes:
      card.creatorNotes = value;
  }
}
