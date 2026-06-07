/// The distinct parts a chat prompt is assembled from, in roughly the order
/// they fill the model's context. Each carries a short label for the
/// breakdown bar's legend and detail dialog. `reservedReply` is not part of
/// the text sent to the model — it is the slice the builder holds back for
/// the answer.
enum PromptSegmentKindEnum {
  identity('Identity'),
  systemPrompt('System prompt'),
  nsfwMode('NSFW mode'),
  scenarioMode('Scenario mode'),
  description('Description'),
  personality('Personality'),
  scenario('Scenario'),
  userPersona('Your persona'),
  memory('Memory'),
  situation('Situation'),
  cardData('Card data'),
  tools('Tools'),
  postHistory('Post-history'),
  depthPrompt('Depth prompt'),
  worldInfo('World info'),
  injected('Injected'),
  exampleDialogue('Example dialogue'),
  history('Message history'),
  currentMessage('Current message'),
  reservedReply('Reserved reply');

  const PromptSegmentKindEnum(this.label);
  final String label;
}
