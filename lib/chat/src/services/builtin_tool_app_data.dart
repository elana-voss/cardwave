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
  const ChatBuiltinToolAppData({
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
}
