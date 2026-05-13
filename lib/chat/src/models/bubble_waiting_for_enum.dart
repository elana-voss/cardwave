/// What an assistant bubble is currently waiting on. Drives the bubble's
/// progress indicator (small spinner + label below the content). The
/// active swipe carries the value; `complete` is the terminal state and
/// hides the indicator.
///
/// Replaces three older mechanisms that previously fought over loading
/// state: `isPlaceholder` bool, italic-markdown content writes
/// (`*Generating video…*`), and the `streamingContent` notifier's
/// per-tool overlays. The enum is the single source of truth.
enum BubbleWaitingForEnum {
  /// Default. No indicator.
  complete,

  /// LLM call in flight, no tokens yet, or between tool-loop iterations.
  callingLlm,

  /// Tokens are streaming into `content`. Indicator is hidden — the
  /// streaming text itself is the progress signal.
  streamingText,

  /// A tool is dispatching. The label comes from the tool's own
  /// `progressLabel` and is supplied via `waitingForLabel` (the enum
  /// case alone doesn't know which tool).
  runningTool,

  /// System-LLM compactor building an image-gen prompt.
  composingImagePrompt,

  /// System-LLM compactor building a video-gen prompt.
  composingVideoPrompt,

  /// Image provider call in flight.
  generatingImage,

  /// Video provider call in flight (submit / poll / download). The
  /// bubble may further refine the label from the active job's phase
  /// when one is registered with `VideoGenerationService`.
  generatingVideo,
}

extension BubbleWaitingForEnumX on BubbleWaitingForEnum {
  /// Whether the bubble should render the spinner + label row. False
  /// for `complete` (terminal) and `streamingText` (streaming text is
  /// its own progress signal).
  bool get showsIndicator =>
      this != BubbleWaitingForEnum.complete &&
      this != BubbleWaitingForEnum.streamingText;

  /// Default label shown next to the spinner. `runningTool` returns
  /// empty because the tool's own label is always supplied externally
  /// via `ChatSwipe.waitingForLabel`.
  String get defaultLabel {
    switch (this) {
      case BubbleWaitingForEnum.complete:
      case BubbleWaitingForEnum.streamingText:
      case BubbleWaitingForEnum.runningTool:
        return '';
      case BubbleWaitingForEnum.callingLlm:
        return 'Thinking…';
      case BubbleWaitingForEnum.composingImagePrompt:
        return 'Preparing image prompt…';
      case BubbleWaitingForEnum.composingVideoPrompt:
        return 'Preparing video prompt…';
      case BubbleWaitingForEnum.generatingImage:
        return 'Generating image…';
      case BubbleWaitingForEnum.generatingVideo:
        return 'Generating video…';
    }
  }
}
