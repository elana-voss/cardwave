import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_swipe.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

enum ChatRoleEnum {
  @JsonValue('system')
  system,
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
  @JsonValue('character')
  character,
}

@JsonSerializable(explicitToJson: true)
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.timestamp,
    List<ChatSwipe>? swipes,
    this.swipeIndex = 0,
    this.generationTime,
    this.modelUsed,
    this.rawPrompt,
    this.characterId,
  }) : swipes = swipes ?? [];

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
  final ChatRoleEnum role;
  List<ChatSwipe> swipes;
  int swipeIndex;
  final int timestamp;
  int? generationTime;
  String? modelUsed;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? rawPrompt;

  /// Links this message to a character in group chats.
  /// Null for user/system messages and all 1:1 chat messages.
  String? characterId;

  /// The swipe currently shown. Invariant: [swipeIndex] is always within
  /// `swipes` bounds. Callers that can reach an empty [swipes] must guard
  /// that case before reading this.
  @JsonKey(includeFromJson: false, includeToJson: false)
  // ignore: qcheck/avoid_unsafe_collection_methods
  ChatSwipe get activeSwipe => swipes[swipeIndex];

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get content => swipes.isNotEmpty ? activeSwipe.content : '';

  set content(String value) {
    if (swipes.isEmpty) {
      swipes.add(ChatSwipe(content: value));
      swipeIndex = 0;
    } else {
      activeSwipe.content = value;
    }
  }

  /// Delegates to the current swipe's `attachedImages` list, matching the
  /// same pattern as [content] and [tokenCount]. Returns an immutable empty
  /// list if no swipes exist so callers can safely iterate.
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<String> get attachedImages =>
      swipes.isNotEmpty ? activeSwipe.attachedImages : const <String>[];

  set attachedImages(List<String> value) {
    if (swipes.isEmpty) {
      swipes.add(ChatSwipe(content: '', attachedImages: value));
      swipeIndex = 0;
    } else {
      activeSwipe.attachedImages = value;
    }
  }

  /// Caption text on the active swipe, rendered in the bubble underneath
  /// any attached image. Set by the `send_selfie` tool.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get imageCaption =>
      swipes.isNotEmpty ? activeSwipe.imageCaption : null;

  set imageCaption(String? value) {
    if (swipes.isEmpty) {
      swipes.add(ChatSwipe(content: '', imageCaption: value));
      swipeIndex = 0;
    } else {
      activeSwipe.imageCaption = value;
    }
  }

  /// Generated MP4 path on the active swipe, if any.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get videoPath => swipes.isNotEmpty ? activeSwipe.videoPath : null;

  /// Loading-state enum on the active swipe — drives the bubble's
  /// progress indicator. Setter is a no-op when there are no swipes
  /// (the bubble has nothing to render against).
  @JsonKey(includeFromJson: false, includeToJson: false)
  BubbleWaitingForEnum get waitingFor => swipes.isNotEmpty
      ? activeSwipe.waitingFor
      : BubbleWaitingForEnum.complete;

  set waitingFor(BubbleWaitingForEnum value) {
    if (swipes.isNotEmpty) activeSwipe.waitingFor = value;
  }

  /// Override label that pairs with [waitingFor] (tool name, video job
  /// phase, etc.). Null falls back to `waitingFor.defaultLabel`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get waitingForLabel =>
      swipes.isNotEmpty ? activeSwipe.waitingForLabel : null;

  set waitingForLabel(String? value) {
    if (swipes.isNotEmpty) activeSwipe.waitingForLabel = value;
  }

  void addSwipe(String newContent) {
    swipes.add(ChatSwipe(content: newContent));
    swipeIndex = swipes.length - 1;
  }

  /// True when the active swipe carries any kind of generated media —
  /// image bytes (`attachedImages`) or an MP4 path (`videoPath`). Used by
  /// the image and video prompt builders to exclude `*(sent an image: …)*`
  /// and `*(sent a video: …)*` markers from the "recent chat history"
  /// slice fed to the compactor LLM: without this, a second `lastMessage`
  /// generation right after the first one would describe its own prior
  /// output marker instead of the original conversational reply.
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasMediaAttachments {
    if (swipes.isEmpty) return false;
    final swipe = activeSwipe;
    if (swipe.attachedImages.isNotEmpty) return true;
    return swipe.videoPath != null;
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  int? get tokenCount => swipes.isNotEmpty ? activeSwipe.tokenCount : null;

  set tokenCount(int? value) {
    if (swipes.isNotEmpty) {
      activeSwipe.tokenCount = value;
    }
  }

  void nextSwipe() {
    if (swipeIndex < swipes.length - 1) swipeIndex++;
  }

  void previousSwipe() {
    if (swipeIndex > 0) swipeIndex--;
  }

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
}
