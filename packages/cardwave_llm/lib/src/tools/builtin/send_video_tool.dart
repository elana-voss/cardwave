import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/tools/builtin/builtin_tool_app_data.dart';
import 'package:cardwave_llm/src/tools/tool_call_context.dart';
import 'package:cardwave_llm/src/tools/tool_definition.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';
import 'package:cardwave_llm/src/video/video_generation_mode_enum.dart';

/// Second media-attachment builtin (sister of `send_selfie`). Lets the chat
/// model attach a short generated video clip to its reply, driven by
/// purpose / emotion / motion / framing rather than raw video keywords.
/// Schema fields are folded into a single intent string that fills the
/// `{{subject}}` slot of the selfie video-gen template; the system model
/// then expands using chat history (location, lighting, outfit) the tool
/// args don't restate.
class SendVideoTool extends ToolDefinition {
  const SendVideoTool({
    required this.promptRepository,
    required this.maxCallsPerTurn,
  });

  /// Stable name referenced from outside the tools layer (drawer toggle,
  /// chat-execution allowed-tools list) so changing the wire-format string
  /// is a single edit instead of a grep-and-replace across the codebase.
  static const String toolName = 'send_video';

  final PromptRepository promptRepository;
  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Attach a short video clip to your reply. Use when sharing a moving '
      'moment about yourself — a gesture, a glance, a small piece of your '
      'day. The clip is generated server-side; you only describe what to '
      'convey.';

  @override
  String get systemPromptText => promptRepository.toolSendVideoAdvertisement;

  @override
  String get progressLabel => 'Sending video…';

  static const Map<String, Object?> _properties = {
    'purpose': {
      'type': 'string',
      'description': 'What you are communicating by sending this clip.',
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
    'motion': {
      'type': 'string',
      'description':
          'The dominant motion in the clip. Video models reject static '
          'descriptions — pick one even when subtle.',
      'enum': [
        'still_breath',
        'slow_smile',
        'looking_around',
        'turning_to_camera',
        'walking',
        'gesturing',
        'hair_brush',
        'lean_in',
        'lean_back',
        'nod',
        'shrug',
        'wave',
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
    return const {
      'type': 'object',
      'required': ['purpose', 'emotion', 'motion'],
      'properties': _properties,
    };
  }

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final purpose = args['purpose'] as String?;
    final emotion = args['emotion'] as String?;
    final motion = args['motion'] as String?;
    if (purpose == null || emotion == null || motion == null) {
      return const ToolResult.failure(
        'send_video missing required field (purpose / emotion / motion).',
      );
    }

    final data = ctx.appData as BuiltinToolAppData;
    final intent = _composeIntent(args);
    await data.generateVideo(
      mode: VideoGenerationModeEnum.selfie,
      freePrompt: intent,
    );
    return const ToolResult.ok();
  }

  /// Packs the schema fields into one comma-separated intent string that
  /// fills `{{subject}}` in the selfie video template. The system model
  /// then expands this plus chat history into the final T2V prose prompt.
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
    addIfPresent('motion', 'motion');
    addIfPresent('expression', 'expression');
    addIfPresent('framing', 'framing');
    addIfPresent('gaze', 'gaze');
    addIfPresent('what_shown', 'what shown');
    return parts.join(', ');
  }
}
