import 'package:cardwave/character/src/models/character_card_envelope.dart';
import 'package:cardwave/character/src/models/character_card_v2.dart';
import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as p;

part 'character_file.g.dart';

CharacterCardV3 _cardFromJson(Map<String, dynamic> json) {
  final envelope = CharacterCardEnvelope.fromJson(json);
  if (envelope.spec == 'chara_card_v2' || envelope.specVersion == '2.0') {
    return CharacterCardV2.fromJson(envelope.data).toV3();
  }
  return CharacterCardV3.fromJson(envelope.data);
}

Map<String, dynamic> _cardToJson(CharacterCardV3 card) {
  final envelope = CharacterCardEnvelope(
    spec: 'chara_card_v3',
    specVersion: '3.0',
    data: card.toJson(),
  );
  return envelope.toJson();
}

@JsonSerializable(checked: true, explicitToJson: true)
class CharacterFile {
  CharacterFile({
    required this.card,
    required this.pngTimestampImported,
    required this.pngTimestampLastSaved,
    required this.appCardTokenCountPermanent,
    required this.appCardTokenCountAll,
    required this.appCardTokenCountLorebook,
    required this.appCardVariantNotes,
    required this.appCardIsArchive,
    required this.appCardId,
    required this.appCardRootId,
    required this.appCardParentId,
    this.appCardTimestampLastChatted,
    this.appCardTimestampLastChattedDismissed,
    this.appCardTimestampLastSaved,
    this.appCardTags = const <String>{},
    this.configMedia,
  });

  factory CharacterFile.fromJson(Map<String, dynamic> json) =>
      _$CharacterFileFromJson(json);
  @JsonKey(fromJson: _cardFromJson, toJson: _cardToJson)
  CharacterCardV3 card;

  @JsonKey(includeFromJson: false, includeToJson: false)
  /// PNG path
  late String appCardImagePath;

  /// PNG initial import time
  int pngTimestampImported;

  /// PNG last save time (or initial import time)
  int pngTimestampLastSaved;

  int appCardTokenCountPermanent;

  int appCardTokenCountAll;

  int appCardTokenCountLorebook;

  int? appCardTimestampLastChatted;

  int? appCardTimestampLastChattedDismissed;

  /// Timestamp of last JSON cache save
  int? appCardTimestampLastSaved;

  @JsonKey(defaultValue: <String>{})
  Set<String> appCardTags;

  String appCardVariantNotes;

  bool appCardIsArchive;

  /// UUID app wide.
  /// Generated on creation, cloning, or import.
  String appCardId;

  /// For handling variants of a card,
  /// referencing original/master-appCardId
  /// of a group this card belongs to.
  /// The original and all variants within a group
  /// share [appCardRootId].
  String appCardRootId;

  /// For handling variants of a card,
  /// referencing the direct parent to establish
  /// a hierarchy within a group.
  String appCardParentId;

  /// Per-character media generation settings — every per-domain preset id,
  /// secondary fields (aspect / resolution / voice / language), prompt
  /// prefixes, NSFW gates, and tool flags the card author wants to ship.
  /// Null when the character has no overrides and the resolver should fall
  /// through to the app-layer defaults entirely. See [ConfigMediaCharacter]
  /// for the full field set.
  @JsonKey(includeIfNull: false)
  ConfigMediaCharacter? configMedia;
  Map<String, dynamic> toJson() => _$CharacterFileToJson(this);

  /// Base cache folder for this character: `characters/<withoutExt(imagePath)>/`.
  /// All per-character cache data lives here (card.json, card.thumb.png, chats/).
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get appCardCharacterFolder {
    return p.posix.join(
      AppConstants.customCacheCharacterPath,
      p.posix.withoutExtension(appCardImagePath),
    );
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get appCardThumbnailPath =>
      p.posix.join(appCardCharacterFolder, AppConstants.cardThumbnailFileName);

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get appCardJsonPath =>
      p.posix.join(appCardCharacterFolder, AppConstants.cardJsonFileName);

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get appCardChatsFolder =>
      p.posix.join(appCardCharacterFolder, 'chats');

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isDirty => (appCardTimestampLastSaved ?? 0) > pngTimestampLastSaved;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isRecent {
    final chatted = appCardTimestampLastChatted ?? 0;
    if (chatted == 0) return false;

    final dismissed = appCardTimestampLastChattedDismissed ?? 0;
    if (dismissed >= chatted) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    return chatted > (now - thirtyDaysMs);
  }

  Future<void> updateTokenCounts() async {
    final textPerm = [
      card.name,
      if (card.nickname != null) card.nickname!,
      if (card.systemName != null) card.systemName!,
      card.description,
      card.personality,
      card.scenario,
    ].join('\n');

    final textTotal = [card.firstMes, card.mesExample].join('\n');

    final textLore =
        card.lorebook?.entries.map((e) => e.content ?? '').join('\n') ?? '';

    final results = await Future.wait([
      UtilsLlm.countTokens(textPerm),
      UtilsLlm.countTokens(textTotal),
      UtilsLlm.countTokens(textLore),
    ]);

    appCardTokenCountPermanent = results.first;
    appCardTokenCountAll = results[1] + results.first;
    appCardTokenCountLorebook = results[2];
  }
}
