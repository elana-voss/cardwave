import 'package:cardwave_llm/src/image/image_generation_mode_enum.dart';
import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/tools/builtin/builtin_tool_app_data.dart';
import 'package:cardwave_llm/src/tools/tool_call_context.dart';
import 'package:cardwave_llm/src/tools/tool_definition.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';

/// First builtin tool. Lets the chat model attach a selfie to its reply,
/// driven by purpose / emotion / framing / caption rather than raw image
/// keywords. Schema fields are folded into a single intent string that
/// fills the `{{subject}}` slot of the selfie image-gen template; the
/// system model then expands using chat history (location, lighting,
/// outfit) the tool args don't restate.
class SendSelfieTool extends ToolDefinition {
  const SendSelfieTool({
    required this.promptRepository,
    required this.maxCallsPerTurn,
  });

  /// Stable name referenced from outside the tools layer (drawer toggle,
  /// chat-execution allowed-tools list) so changing the wire-format string
  /// is a single edit instead of a grep-and-replace across the codebase.
  static const String toolName = 'send_selfie';

  final PromptRepository promptRepository;
  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Attach a selfie image to your reply. Use when sharing something '
      'visual about yourself — your mood, what you are doing, an outfit. '
      'The image is generated server-side; you only describe what to convey.';

  @override
  String get systemPromptText => promptRepository.toolSendSelfieAdvertisement;

  @override
  String get progressLabel => 'Sending selfie…';

  static const Map<String, Object?> _captionField = {
    'type': 'string',
    'description':
        'The words rendered on or with the image — what you are '
        'saying alongside the photo. Kept verbatim.',
  };

  static const Map<String, Object?> _baseProperties = {
    'purpose': {
      'type': 'string',
      'description': 'What you are communicating by sending this selfie.',
      'enum': [
        'greeting',
        'showing_off',
        'sharing_moment',
        'seeking_validation',
        'flirting',
        'seductive',
        'lewd',
        'venting',
        'inside_joke',
        'proof_of_life',
        'update',
        'comfort',
        'playful',
        'vulnerable',
        'celebratory',
      ],
    },
    'emotion': {
      'type': 'string',
      'description': 'Your felt state right now.',
      'enum': [
        'happy',
        'content',
        'excited',
        'tired',
        'sad',
        'lonely',
        'anxious',
        'angry',
        'bored',
        'calm',
        'affectionate',
        'longing',
        'silly',
        'mischievous',
        'neutral',
      ],
    },
    'expression': {
      'type': 'string',
      'description': 'What the face shows. Defaults derived from emotion.',
      'enum': [
        'neutral',
        'soft_smile',
        'wide_smile',
        'laughing',
        'smirk',
        'pout',
        'wink',
        'surprised',
        'contemplative',
        'wistful',
        'mid_laugh',
        'tongue_out',
      ],
    },
    'framing': {
      'type': 'string',
      'description': 'How much of yourself is in the shot.',
      'enum': [
        'close_up',
        'head_and_shoulders',
        'chest_up',
        'waist_up',
        'full_body',
        'mirror_full',
      ],
    },
    'gaze': {
      'type': 'string',
      'description': 'Where the eyes are pointed.',
      'enum': [
        'at_camera',
        'away_thoughtful',
        'closed_eyes',
        'looking_up',
        'side_eye',
      ],
    },
    'what_shown': {
      'type': 'string',
      'description':
          'Free-text override for visual specifics not captured by the '
          'enums (lingerie, an object you are holding, a particular '
          'outfit, etc.).',
    },
  };

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) {
    // Schema-gen and execute both cast through BuiltinToolSchemaContext;
    // BuiltinToolAppData implements it, so the per-iteration full impl
    // works here too. Caller picks the lightweight schema-only impl when
    // no target message exists yet.
    final ctx = appData as BuiltinToolSchemaContext;
    final captionsOn = ctx.imageToolSelfieCaptionsAllowed;
    return {
      'type': 'object',
      'required': captionsOn
          ? const ['purpose', 'emotion', 'caption']
          : const ['purpose', 'emotion'],
      'properties': captionsOn
          ? {..._baseProperties, 'caption': _captionField}
          : _baseProperties,
    };
  }

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final purpose = args['purpose'] as String?;
    final emotion = args['emotion'] as String?;
    if (purpose == null || emotion == null) {
      return const ToolResult.failure(
        'send_selfie missing required field (purpose / emotion).',
      );
    }
    final data = ctx.appData as BuiltinToolAppData;
    // Caption is dropped from the schema when the session disables it,
    // but ignore any caption the model may have produced from training
    // data so the bubble doesn't show one the user opted out of.
    final captionsOn = data.imageToolSelfieCaptionsAllowed;
    final caption = captionsOn ? args['caption'] as String? : null;

    final intent = _composeIntent(args);
    await data.generateImage(
      mode: ImageGenerationModeEnum.selfie,
      freePrompt: intent,
      caption: caption,
    );
    return const ToolResult.ok();
  }

  /// Packs the schema fields into one comma-separated intent string that
  /// fills `{{subject}}` in the selfie template. The system model then
  /// expands this plus chat history into the actual image-gen tag list.
  String _composeIntent(Map<String, dynamic> args) {
    final parts = <String>[];
    void addIfPresent(String key, [String? prefix]) {
      final v = args[key];
      if (v is String && v.trim().isNotEmpty) {
        parts.add(prefix == null ? v.trim() : '$prefix: ${v.trim()}');
      }
    }

    addIfPresent('purpose', 'purpose');
    addIfPresent('emotion', 'emotion');
    addIfPresent('expression', 'expression');
    addIfPresent('framing', 'framing');
    addIfPresent('gaze', 'gaze');
    addIfPresent('what_shown', 'what shown');
    return parts.join(', ');
  }
}
