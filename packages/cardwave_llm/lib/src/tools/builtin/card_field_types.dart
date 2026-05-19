/// Scalar string fields on the character card the assistant can read or
/// write via the `card_field_*` tools. `jsonKey` is the snake-case wire
/// name matching `CharacterCardV3` JSON keys.
enum CardFieldScalar {
  name('name'),
  description('description'),
  personality('personality'),
  scenario('scenario'),
  firstMes('first_mes'),
  mesExample('mes_example'),
  systemPrompt('system_prompt'),
  postHistoryInstructions('post_history_instructions'),
  creatorNotes('creator_notes');

  const CardFieldScalar(this.jsonKey);

  final String jsonKey;

  static CardFieldScalar? fromJsonKey(String key) {
    for (final v in values) {
      if (v.jsonKey == key) return v;
    }
    return null;
  }
}

/// List-of-string fields on the character card.
enum CardFieldList {
  alternateGreeting('alternate_greeting'),
  groupOnlyGreeting('group_only_greeting'),
  tag('tag');

  const CardFieldList(this.jsonKey);

  final String jsonKey;

  static CardFieldList? fromJsonKey(String key) {
    for (final v in values) {
      if (v.jsonKey == key) return v;
    }
    return null;
  }
}

/// Classification used by the approval gate to decide whether a proposal
/// needs user confirmation. The mapping rule:
///   set(scalar, "") / list_set(_, _, "")  → deletion (data is being cleared)
///   set(scalar, non-empty) / list_set(non-empty) → edit
///   list_append                            → addition
///   list_delete                            → deletion
enum CardEditModality { edit, addition, deletion }

/// One proposed change recorded during the dispatcher's propose pass.
/// Sealed so apply / dialog rendering can switch on the variant and read
/// only the fields that variant carries.
sealed class CardEditProposal {
  const CardEditProposal();

  CardEditModality get modality;

  /// Human-readable location label, e.g. 'description', 'alternate_greeting[2]'.
  String get fieldLabel;
}

class CardScalarSetProposal extends CardEditProposal {
  const CardScalarSetProposal({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  final CardFieldScalar field;
  final String oldValue;
  final String newValue;

  @override
  CardEditModality get modality =>
      newValue.isEmpty ? CardEditModality.deletion : CardEditModality.edit;

  @override
  String get fieldLabel => field.jsonKey;
}

class CardListSetProposal extends CardEditProposal {
  const CardListSetProposal({
    required this.field,
    required this.index,
    required this.oldValue,
    required this.newValue,
  });

  final CardFieldList field;
  final int index;
  final String oldValue;
  final String newValue;

  @override
  CardEditModality get modality =>
      newValue.isEmpty ? CardEditModality.deletion : CardEditModality.edit;

  @override
  String get fieldLabel => '${field.jsonKey}[$index]';
}

class CardListAppendProposal extends CardEditProposal {
  const CardListAppendProposal({
    required this.field,
    required this.newValue,
  });

  final CardFieldList field;
  final String newValue;

  @override
  CardEditModality get modality => CardEditModality.addition;

  @override
  String get fieldLabel => '${field.jsonKey}[+]';
}

class CardListDeleteProposal extends CardEditProposal {
  const CardListDeleteProposal({
    required this.field,
    required this.index,
    required this.oldValue,
  });

  final CardFieldList field;
  final int index;
  final String oldValue;

  @override
  CardEditModality get modality => CardEditModality.deletion;

  @override
  String get fieldLabel => '${field.jsonKey}[$index]';
}
