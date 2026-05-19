import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// App-side concrete implementation of the package's [BuiltinToolAppData].
/// Carries the chat-domain references the closures need to attach generated
/// media / confirm fetches against the in-flight bubble. The package treats
/// this as opaque inside `ToolCallContext.appData`; the builtin tools cast
/// it back via the abstract base.
class ChatBuiltinToolAppData implements BuiltinToolAppData {
  ChatBuiltinToolAppData({
    required this.session,
    required this.character,
    required this.targetMessage,
    required Future<void> Function({
      required ImageGenerationModeEnum mode,
      String? freePrompt,
      String? caption,
    })
    generateImageImpl,
    required Future<void> Function({
      required VideoGenerationModeEnum mode,
      String? freePrompt,
    })
    generateVideoImpl,
    required Future<bool> Function(String url, {String? purpose})
    confirmFetchImpl,
  }) : _generateImageImpl = generateImageImpl,
       _generateVideoImpl = generateVideoImpl,
       _confirmFetchImpl = confirmFetchImpl;

  final ChatSession session;
  final CharacterFile? character;
  final ChatMessage targetMessage;

  final Future<void> Function({
    required ImageGenerationModeEnum mode,
    String? freePrompt,
    String? caption,
  })
  _generateImageImpl;
  final Future<void> Function({
    required VideoGenerationModeEnum mode,
    String? freePrompt,
  })
  _generateVideoImpl;
  final Future<bool> Function(String url, {String? purpose}) _confirmFetchImpl;

  final List<CardEditProposal> _cardEditBatch = [];

  @override
  bool get imageToolSelfieCaptionsAllowed =>
      session.configMedia?.imageToolSelfieCaptionsAllowed ?? false;

  @override
  Future<void> generateImage({
    required ImageGenerationModeEnum mode,
    String? freePrompt,
    String? caption,
  }) =>
      _generateImageImpl(mode: mode, freePrompt: freePrompt, caption: caption);

  @override
  Future<void> generateVideo({
    required VideoGenerationModeEnum mode,
    String? freePrompt,
  }) => _generateVideoImpl(mode: mode, freePrompt: freePrompt);

  @override
  Future<bool> confirmFetch(String url, {String? purpose}) =>
      _confirmFetchImpl(url, purpose: purpose);

  @override
  Set<String> get usedFirstNames => session.usedFirstNames;

  @override
  Set<String> get usedLastNames => session.usedLastNames;

  // --- Card edit reads -------------------------------------------------------

  @override
  String readScalar(CardFieldScalar field) {
    final card = character?.card;
    return card == null ? '' : readScalarField(card, field);
  }

  @override
  int listSize(CardFieldList field) {
    final card = character?.card;
    return card == null ? 0 : listFieldOf(card, field).length;
  }

  @override
  String readListEntry(CardFieldList field, int index) {
    final card = character?.card;
    if (card == null) return '';
    final list = listFieldOf(card, field);
    if (index < 0 || index >= list.length) return '';
    // Bounds checked above.
    // ignore: qcheck/avoid_unsafe_collection_methods
    return list[index];
  }

  // --- Card edit proposals ---------------------------------------------------

  @override
  ToolResult proposeScalarSet(CardFieldScalar field, String content) {
    if (character == null) return const ToolResult.failure('no card open');
    _cardEditBatch.add(CardScalarSetProposal(
      field: field,
      oldValue: readScalar(field),
      newValue: content,
    ));
    return const ToolResult.ok();
  }

  @override
  ToolResult proposeListSet(CardFieldList field, int index, String content) {
    final card = character?.card;
    if (card == null) return const ToolResult.failure('no card open');
    final list = listFieldOf(card, field);
    if (index < 0 || index >= list.length) {
      return ToolResult.failure(
        'index out of bounds; list has ${list.length} entries.',
      );
    }
    _cardEditBatch.add(CardListSetProposal(
      field: field,
      index: index,
      // Bounds checked above.
      // ignore: qcheck/avoid_unsafe_collection_methods
      oldValue: list[index],
      newValue: normalizeFieldValue(field, content),
    ));
    return const ToolResult.ok();
  }

  @override
  ToolResult proposeListAppend(CardFieldList field, String content) {
    if (character == null) return const ToolResult.failure('no card open');
    _cardEditBatch.add(CardListAppendProposal(
      field: field,
      newValue: normalizeFieldValue(field, content),
    ));
    return const ToolResult.ok();
  }

  @override
  ToolResult proposeListDelete(CardFieldList field, int index) {
    final card = character?.card;
    if (card == null) return const ToolResult.failure('no card open');
    final list = listFieldOf(card, field);
    if (index < 0 || index >= list.length) {
      return ToolResult.failure(
        'index out of bounds; list has ${list.length} entries.',
      );
    }
    _cardEditBatch.add(CardListDeleteProposal(
      field: field,
      index: index,
      // Bounds checked above.
      // ignore: qcheck/avoid_unsafe_collection_methods
      oldValue: list[index],
    ));
    return const ToolResult.ok();
  }

  @override
  void beginCardEditBatch() {
    _cardEditBatch.clear();
  }

  @override
  List<CardEditProposal> takeBatch() {
    final out = List<CardEditProposal>.unmodifiable(_cardEditBatch);
    _cardEditBatch.clear();
    return out;
  }

  /// Mutates the card in place to apply the given approved proposals. Caller
  /// wraps this in [CharacterService.applyExternalCardEdits] which handles
  /// save + notify after the mutation completes. Application order and
  /// overlap rules live with the character-domain helper.
  void applyApprovedProposals(Iterable<CardEditProposal> approved) {
    final card = character?.card;
    if (card == null) return;
    applyCardEditProposals(card, approved);
  }
}
