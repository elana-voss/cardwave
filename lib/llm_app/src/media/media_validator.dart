import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Walks [session.configMedia] and clears any preset id whose preset no
/// longer resolves against [providers]. Paired setters are used so the
/// secondary tuple fields (aspect / resolution / voice / language /
/// duration) clear together with the preset id and stay coherent.
///
/// Heals in memory only — the disk file stays dirty until the next
/// normal save fires. See the stale-preset validation plan for the
/// no-forced-save rationale.
void validateConfigMediaSession({
  required ChatSession session,
  required List<LlmProviderConfig> providers,
  required LlmPureHelpers pureHelpers,
}) {
  final cm = session.configMedia;
  if (cm == null) return;

  final imageId = cm.imagePresetId;
  if (imageId != null &&
      pureHelpers.resolvePresetOrNull(
            configId: imageId,
            providers: providers,
          ) ==
          null) {
    cm.setImagePreset(null, null);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'media-validator: nulled image preset $imageId on session ${session.id}',
      ),
    );
  }
  final videoId = cm.videoPresetId;
  if (videoId != null &&
      pureHelpers.resolvePresetOrNull(
            configId: videoId,
            providers: providers,
          ) ==
          null) {
    cm.setVideoPreset(null, null, null, null);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'media-validator: nulled video preset $videoId on session ${session.id}',
      ),
    );
  }
  final ttsId = cm.ttsPresetId;
  if (ttsId != null &&
      pureHelpers.resolvePresetOrNull(configId: ttsId, providers: providers) ==
          null) {
    cm.setTtsPreset(null, null, null);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'media-validator: nulled tts preset $ttsId on session ${session.id}',
      ),
    );
  }
}

/// Walks [character.configMedia] and clears any preset id whose preset
/// no longer resolves against [providers]. See [validateConfigMediaSession]
/// for the heal-in-memory contract.
void validateConfigMediaCharacter({
  required CharacterFile character,
  required List<LlmProviderConfig> providers,
  required LlmPureHelpers pureHelpers,
}) {
  final cm = character.configMedia;
  if (cm == null) return;

  final imageId = cm.imagePresetId;
  if (imageId != null &&
      pureHelpers.resolvePresetOrNull(
            configId: imageId,
            providers: providers,
          ) ==
          null) {
    cm.setImagePreset(null, null);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'media-validator: nulled image preset $imageId on character '
            '${character.appCardId}',
      ),
    );
  }
  final videoId = cm.videoPresetId;
  if (videoId != null &&
      pureHelpers.resolvePresetOrNull(
            configId: videoId,
            providers: providers,
          ) ==
          null) {
    cm.setVideoPreset(null, null, null, null);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'media-validator: nulled video preset $videoId on character '
            '${character.appCardId}',
      ),
    );
  }
  final ttsId = cm.ttsPresetId;
  if (ttsId != null &&
      pureHelpers.resolvePresetOrNull(configId: ttsId, providers: providers) ==
          null) {
    cm.setTtsPreset(null, null, null);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'media-validator: nulled tts preset $ttsId on character '
            '${character.appCardId}',
      ),
    );
  }
}
