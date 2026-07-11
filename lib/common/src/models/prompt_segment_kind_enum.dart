import 'package:cardwave/i18n/gen/translations.g.dart';

/// The distinct parts a chat prompt is assembled from, in roughly the order
/// they fill the model's context. Each carries a short label for the
/// breakdown bar's legend and detail dialog. `reservedReply` is not part of
/// the text sent to the model — it is the slice the builder holds back for
/// the answer.
enum PromptSegmentKindEnum {
  identity,
  systemPrompt,
  nsfwMode,
  scenarioMode,
  description,
  personality,
  scenario,
  userPersona,
  memory,
  situation,
  cardData,
  tools,
  postHistory,
  depthPrompt,
  worldInfo,
  injected,
  exampleDialogue,
  history,
  currentMessage,
  reservedReply;

  String get label => switch (this) {
    PromptSegmentKindEnum.identity => t.common.promptSegmentKind.identity,
    PromptSegmentKindEnum.systemPrompt =>
      t.common.promptSegmentKind.systemPrompt,
    PromptSegmentKindEnum.nsfwMode => t.common.promptSegmentKind.nsfwMode,
    PromptSegmentKindEnum.scenarioMode =>
      t.common.promptSegmentKind.scenarioMode,
    PromptSegmentKindEnum.description =>
      t.common.promptSegmentKind.description,
    PromptSegmentKindEnum.personality =>
      t.common.promptSegmentKind.personality,
    PromptSegmentKindEnum.scenario => t.common.promptSegmentKind.scenario,
    PromptSegmentKindEnum.userPersona =>
      t.common.promptSegmentKind.userPersona,
    PromptSegmentKindEnum.memory => t.common.promptSegmentKind.memory,
    PromptSegmentKindEnum.situation => t.common.promptSegmentKind.situation,
    PromptSegmentKindEnum.cardData => t.common.promptSegmentKind.cardData,
    PromptSegmentKindEnum.tools => t.common.promptSegmentKind.tools,
    PromptSegmentKindEnum.postHistory =>
      t.common.promptSegmentKind.postHistory,
    PromptSegmentKindEnum.depthPrompt =>
      t.common.promptSegmentKind.depthPrompt,
    PromptSegmentKindEnum.worldInfo => t.common.promptSegmentKind.worldInfo,
    PromptSegmentKindEnum.injected => t.common.promptSegmentKind.injected,
    PromptSegmentKindEnum.exampleDialogue =>
      t.common.promptSegmentKind.exampleDialogue,
    PromptSegmentKindEnum.history => t.common.promptSegmentKind.history,
    PromptSegmentKindEnum.currentMessage =>
      t.common.promptSegmentKind.currentMessage,
    PromptSegmentKindEnum.reservedReply =>
      t.common.promptSegmentKind.reservedReply,
  };
}
