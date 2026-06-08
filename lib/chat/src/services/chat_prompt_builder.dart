import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/services/lorebook_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

class ChatPromptBuilder {
  ChatPromptBuilder({
    required this.contextSize,
    required this.maxResponseLength,
    required this.session,
    required this.characterFile,
    required this.settingsService,
    required this.promptRepository,
    required this.toolRegistry,
    this.injectedMessage,
    this.isImpersonating = false,
    this.dataContext,
    this.memoryContext,
    this.nodesContext,
    this.enabledTools = const [],
  }) : _charName = (characterFile.card.nickname?.isNotEmpty == true)
           ? characterFile.card.nickname!
           : characterFile.card.name,
       _localVariables = session.localVariables,
       _globalVariables = settingsService.settings.globalVariables;
  static const int _defaultDepthPromptDepth = 4;
  static const String _defaultDepthPromptRole = 'system';
  static const double _defaultMaxResponseReserveRatio = 0.1;
  static const int _exampleWrapperSafetyMargin = 10;
  static const double _exampleTruncationRatioSafetyMargin = 0.95;
  static const int _defaultInsertionOrder = 100;

  final int contextSize;
  final int? maxResponseLength;
  final ChatSession session;
  final CharacterFile characterFile;
  final SettingsService settingsService;
  final PromptRepository promptRepository;
  final ChatMessage? injectedMessage;
  final bool isImpersonating;
  final String? dataContext;

  /// Retrieved story-memory lines for the `<memory>` prompt section. Its own
  /// section — never folded into [dataContext], which assistant-mode card JSON
  /// owns. Null or empty ⇒ no section.
  final String? memoryContext;

  /// Assembled NODES dynamic content (scene + state slice + sticky directives
  /// + this-turn payloads + surfaced memories) for the `<situation>` prompt
  /// section. Built before the actor call by `NodesService.assembleNodesPrompt`.
  /// Null or empty ⇒ no section.
  final String? nodesContext;

  /// Tools enabled for this generation, derived from per-domain tool flags
  /// on the session's media config and gated by `model.capabilities.toolCalling`.
  /// The registry uses these to build the system-prompt advertisement; the
  /// runner gets the equivalent genkit tool list separately. Empty list ⇒
  /// no advertisement section.
  final List<ToolDefinition> enabledTools;
  final ToolRegistry toolRegistry;

  int _currentTokenCount = 0;
  final List<PromptSegmentEntry> _segments = [];
  int _reservedReply = 0;
  final List<LlmRunnerMessage> _messages = [];
  final List<({LlmRunnerMessage msg, int depth})> _depthInsertionMessages = [];
  LlmRunnerMessage? _postHistoryMsg;
  LlmRunnerMessage? _depthPromptMsg;
  int _depthPromptDepth = _defaultDepthPromptDepth;
  LlmRunnerMessage? _lcInjectedMsg;

  final String _charName;
  final Map<String, String> _localVariables;
  final Map<String, String> _globalVariables;

  void _addSection(StringBuffer buffer, String tag, String content) {
    if (content.isEmpty) return;
    buffer.writeln('<$tag>');
    buffer.writeln(content);
    buffer.writeln('</$tag>');
  }

  /// Writes a section and records its token cost as a breakdown segment. The
  /// recorded count is for display only — `_currentTokenCount` stays the
  /// single budgeting truth, counted once over the assembled system message.
  Future<void> _addCountedSection(
    StringBuffer buffer,
    PromptSegmentKindEnum kind,
    String tag,
    String content,
  ) async {
    if (content.isEmpty) return;
    _addSection(buffer, tag, content);
    _segments.add(
      PromptSegmentEntry(
        kind: kind,
        tokens: await UtilsLlm.countTokens(content),
        text: content,
      ),
    );
  }

  /// Counts a standalone prompt message's tokens, adds them to the running
  /// budget, and records the part as a breakdown segment. For messages emitted
  /// outside the combined system buffer (post-history, depth, injected,
  /// examples); [_addCountedSection] handles the buffered sections.
  Future<void> _recordSegment(PromptSegmentKindEnum kind, String content) async {
    final tokens = await UtilsLlm.countTokens(content);
    _currentTokenCount += tokens;
    _segments.add(
      PromptSegmentEntry(kind: kind, tokens: tokens, text: content),
    );
  }

  /// The per-part context breakdown gathered while assembling the prompt. The
  /// real input-token total is filled in by the caller after generation.
  PromptContextBreakdown get breakdown => PromptContextBreakdown(
    contextSize: contextSize,
    reservedReply: _reservedReply,
    segments: List.of(_segments),
  );

  Future<List<LlmRunnerMessage>> build() async {
    final reservation = (contextSize * _defaultMaxResponseReserveRatio).toInt();
    _currentTokenCount = reservation;
    if (maxResponseLength != null && maxResponseLength! > reservation) {
      _currentTokenCount = maxResponseLength!;
    }
    _reservedReply = _currentTokenCount;

    await _buildStaticData();
    await _buildLorebook();
    final historyMessages = await _buildHistory();
    await _buildExamples();
    _assembleFinalMessages(historyMessages);

    return _messages;
  }

  Future<void> _buildStaticData() async {
    final systemBuffer = StringBuffer();

    if (characterFile.card.name.isNotEmpty) {
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.identity,
        'identity',
        'You are ${characterFile.card.name}.',
      );
    }

    await _addCountedSection(
      systemBuffer,
      PromptSegmentKindEnum.systemPrompt,
      'system_prompt',
      characterFile.card.systemPrompt,
    );
    if (session.isNsfw) {
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.nsfwMode,
        'unlimited_nsfw_mode',
        promptRepository.unlimitedMode,
      );
    }
    if (session.isScenario) {
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.scenarioMode,
        'scenario_mode',
        promptRepository.scenarioMode,
      );
    }
    await _addCountedSection(
      systemBuffer,
      PromptSegmentKindEnum.description,
      'description',
      characterFile.card.description,
    );
    await _addCountedSection(
      systemBuffer,
      PromptSegmentKindEnum.personality,
      'personality',
      characterFile.card.personality,
    );
    await _addCountedSection(
      systemBuffer,
      PromptSegmentKindEnum.scenario,
      'scenario',
      characterFile.card.scenario,
    );

    final personaName = session.personaName.trim();
    final personaDescription = session.personaDescription.trim();
    if (personaName.isNotEmpty || personaDescription.isNotEmpty) {
      final personaText = personaDescription.isEmpty
          ? 'Name: $personaName'
          : 'Name: $personaName\n$personaDescription';
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.userPersona,
        'user_persona',
        personaText,
      );
    }

    if (memoryContext != null && memoryContext!.isNotEmpty) {
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.memory,
        'memory',
        memoryContext!,
      );
    }

    if (nodesContext != null && nodesContext!.isNotEmpty) {
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.situation,
        'situation',
        nodesContext!,
      );
    }

    if (dataContext != null && dataContext!.isNotEmpty) {
      await _addCountedSection(
        systemBuffer,
        PromptSegmentKindEnum.cardData,
        'supplemental_data_context',
        dataContext!,
      );
    }

    if (enabledTools.isNotEmpty) {
      final advertisement = toolRegistry.buildSystemPromptAdvertisement(
        enabledTools,
      );
      if (advertisement.isNotEmpty) {
        await _addCountedSection(
          systemBuffer,
          PromptSegmentKindEnum.tools,
          'available_tools',
          advertisement,
        );
      }
    }

    if (systemBuffer.isNotEmpty) {
      final content = UtilsPrompt.replacePlaceholders(
        systemBuffer.toString().trim(),
        charName: _charName,
        userName: session.personaName,
        localVariables: _localVariables,
        globalVariables: _globalVariables,
        trackingId: 'system',
      );
      final msg = LlmRunnerMessage.system(content);
      _messages.add(msg);
      _currentTokenCount += await UtilsLlm.countTokens(msg.content);
    }

    if (characterFile.card.postHistoryInstructions.isNotEmpty) {
      final buffer = StringBuffer();
      _addSection(
        buffer,
        'post_history_instructions',
        characterFile.card.postHistoryInstructions,
      );
      final content = UtilsPrompt.replacePlaceholders(
        buffer.toString().trim(),
        charName: _charName,
        userName: session.personaName,
        localVariables: _localVariables,
        globalVariables: _globalVariables,
        trackingId: 'postHistory',
      );
      final postHistoryMsg = LlmRunnerMessage.system(content);
      _postHistoryMsg = postHistoryMsg;
      await _recordSegment(
        PromptSegmentKindEnum.postHistory,
        postHistoryMsg.content,
      );
    }

    final depthPrompt =
        characterFile.card.extensions['depth_prompt'] as Map<String, dynamic>?;
    if (depthPrompt != null) {
      final rawContent = depthPrompt['prompt'] as String?;

      if (rawContent != null && rawContent.isNotEmpty) {
        final depthVal = depthPrompt['depth'];
        final depth = depthVal is num
            ? depthVal.toInt()
            : _defaultDepthPromptDepth;
        final role =
            depthPrompt['role'] as String? ?? _defaultDepthPromptRole;
        final content = UtilsPrompt.replacePlaceholders(
          rawContent,
          charName: _charName,
          userName: session.personaName,
          localVariables: _localVariables,
          globalVariables: _globalVariables,
          trackingId: 'depthPrompt',
        );
        final LlmRunnerMessage depthMsg;
        if (role == 'user') {
          depthMsg = LlmRunnerMessage.user(content);
        } else if (role == 'assistant') {
          depthMsg = LlmRunnerMessage.assistant(content);
        } else {
          final buffer = StringBuffer();
          _addSection(buffer, 'depth_prompt', content);
          depthMsg = LlmRunnerMessage.system(buffer.toString().trim());
        }
        _depthPromptMsg = depthMsg;
        _depthPromptDepth = depth;
        await _recordSegment(
          PromptSegmentKindEnum.depthPrompt,
          depthMsg.content,
        );
      }
    }

    if (injectedMessage != null) {
      final content = UtilsPrompt.replacePlaceholders(
        injectedMessage!.content,
        charName: _charName,
        userName: session.personaName,
        localVariables: _localVariables,
        globalVariables: _globalVariables,
        trackingId: 'injected',
      );
      switch (injectedMessage!.role) {
        case ChatRoleEnum.user:
          _lcInjectedMsg = LlmRunnerMessage.user(content);
        case ChatRoleEnum.assistant:
        case ChatRoleEnum.character:
          _lcInjectedMsg = LlmRunnerMessage.assistant(content);
        case ChatRoleEnum.system:
          _lcInjectedMsg = LlmRunnerMessage.system(content);
      }
      await _recordSegment(PromptSegmentKindEnum.injected, content);
    }
  }

  Future<void> _buildLorebook() async {
    final lorebookCandidates = LorebookService().evaluate(session, characterFile);
    final acceptedLore =
        <({EvaluatedLorebookEntry candidate, String processedContent})>[];

    final lorebookBudget = characterFile.card.lorebook?.tokenBudget ?? 0;
    var usedLorebookTokens = 0;
    var worldInfoTokens = 0;
    final worldInfoText = StringBuffer();

    for (final candidate in lorebookCandidates) {
      final entry = candidate.entry;
      final ignoreBudget = entry.extensions.ignoreBudget == true;

      final content = UtilsPrompt.replacePlaceholders(
        candidate.content,
        charName: _charName,
        userName: session.personaName,
        localVariables: _localVariables,
        globalVariables: _globalVariables,
        trackingId: 'lorebook_${candidate.uidStr}',
      );

      final cost = await UtilsLlm.countTokens(content);

      if (_currentTokenCount + cost > contextSize) continue;

      if (!ignoreBudget &&
          lorebookBudget > 0 &&
          usedLorebookTokens + cost > lorebookBudget) {
        continue;
      }

      acceptedLore.add((candidate: candidate, processedContent: content));

      _currentTokenCount += cost;
      worldInfoTokens += cost;
      if (worldInfoText.isNotEmpty) worldInfoText.writeln();
      worldInfoText.writeln(content);
      if (!ignoreBudget) {
        usedLorebookTokens += cost;
      }
    }

    LorebookService().commitTimedEffects(
      session,
      acceptedLore.map((e) => e.candidate).toList(),
    );
    acceptedLore.sort(
      (a, b) => (a.candidate.entry.insertionOrder ?? _defaultInsertionOrder)
          .compareTo(
            b.candidate.entry.insertionOrder ?? _defaultInsertionOrder,
          ),
    );

    final lorebookSystemBuffer = StringBuffer();
    final groupedDepthInjections =
        <String, ({String content, int depth, ChatRoleEnum role})>{};

    for (final item in acceptedLore) {
      final candidate = item.candidate;
      final entry = candidate.entry;
      final content = item.processedContent;
      final positionIndex = entry.extensions.position ?? 0;

      if (positionIndex == 4 ||
          entry.position == 'atDepth' ||
          candidate.decoratorOverrideDepth != null) {
        final depth =
            candidate.decoratorOverrideDepth ??
            entry.extensions.depth ??
            _defaultDepthPromptDepth;
        var role = candidate.decoratorOverrideRole ?? ChatRoleEnum.system;

        if (candidate.decoratorOverrideRole == null) {
          final roleInt = entry.extensions.role ?? 0;
          if (roleInt == 1) role = ChatRoleEnum.user;
          if (roleInt == 2) role = ChatRoleEnum.assistant;
        }

        final key = '${depth}_${role.name}';
        if (groupedDepthInjections.containsKey(key)) {
          final existing = groupedDepthInjections[key]!;
          groupedDepthInjections[key] = (
            content: '${existing.content}\n\n$content',
            depth: depth,
            role: role,
          );
        } else {
          groupedDepthInjections[key] = (
            content: content,
            depth: depth,
            role: role,
          );
        }
      } else {
        lorebookSystemBuffer.writeln(content);
        lorebookSystemBuffer.writeln();
      }
    }

    if (lorebookSystemBuffer.isNotEmpty) {
      final sysContent =
          '<world_info>\n${lorebookSystemBuffer.toString().trim()}\n</world_info>';
      _messages.add(LlmRunnerMessage.system(sysContent));
    }

    for (final injection in groupedDepthInjections.values) {
      LlmRunnerMessage msg;
      switch (injection.role) {
        case ChatRoleEnum.user:
          msg = LlmRunnerMessage.user(injection.content);
        case ChatRoleEnum.assistant:
        case ChatRoleEnum.character:
          msg = LlmRunnerMessage.assistant(injection.content);
        case ChatRoleEnum.system:
          msg = LlmRunnerMessage.system(injection.content);
      }
      _depthInsertionMessages.add((msg: msg, depth: injection.depth));
    }

    if (worldInfoTokens > 0) {
      _segments.add(
        PromptSegmentEntry(
          kind: PromptSegmentKindEnum.worldInfo,
          tokens: worldInfoTokens,
          text: worldInfoText.toString().trim(),
        ),
      );
    }
  }

  Future<List<LlmRunnerMessage>> _buildHistory() async {
    final historyMessages = <LlmRunnerMessage>[];
    final latestUserIndex = session.messages.lastIndexWhere(
      (m) => m.role == ChatRoleEnum.user,
    );
    var historyTokens = 0;
    var currentMessageTokens = 0;
    var historyText = '';
    var currentMessageText = '';
    for (var i = session.messages.length - 1; i >= 0; i--) {
      final msg = session.messages[i];

      // Transient UI placeholders (in-flight bubbles still streaming /
      // running tools / generating media) never reach the LLM.
      if (msg.waitingFor != BubbleWaitingForEnum.complete) continue;

      if (!isImpersonating &&
          i == session.messages.length - 1 &&
          msg.content.isEmpty &&
          msg.role == ChatRoleEnum.assistant) {
        continue;
      }

      final content = UtilsPrompt.replacePlaceholders(
        msg.content,
        charName: _charName,
        userName: session.personaName,
        localVariables: _localVariables,
        globalVariables: _globalVariables,
        trackingId: 'history_${msg.timestamp}',
      );

      var tokenCount = msg.tokenCount ?? 0;
      if (tokenCount <= 0 && content.isNotEmpty) {
        tokenCount = await UtilsLlm.countTokens(content);
        msg.tokenCount = tokenCount;
      }

      if (_currentTokenCount + tokenCount > contextSize) {
        break;
      }

      _currentTokenCount += tokenCount;
      if (i == latestUserIndex) {
        currentMessageTokens += tokenCount;
        currentMessageText = content;
      } else {
        historyTokens += tokenCount;
        // The loop runs newest-first; prepend so the inspect text reads
        // oldest-to-newest like the chat does.
        historyText = historyText.isEmpty ? content : '$content\n\n$historyText';
      }

      switch (msg.role) {
        case ChatRoleEnum.system:
          historyMessages.add(LlmRunnerMessage.system(content));
        case ChatRoleEnum.user:
          historyMessages.add(LlmRunnerMessage.user(content));
        case ChatRoleEnum.assistant:
        case ChatRoleEnum.character:
          historyMessages.add(LlmRunnerMessage.assistant(content));
      }
    }

    if (currentMessageTokens > 0) {
      _segments.add(
        PromptSegmentEntry(
          kind: PromptSegmentKindEnum.currentMessage,
          tokens: currentMessageTokens,
          text: currentMessageText,
        ),
      );
    }
    if (historyTokens > 0) {
      _segments.add(
        PromptSegmentEntry(
          kind: PromptSegmentKindEnum.history,
          tokens: historyTokens,
          text: historyText,
        ),
      );
    }
    return historyMessages;
  }

  Future<void> _buildExamples() async {
    if (characterFile.card.mesExample.isNotEmpty) {
      var ex = UtilsPrompt.replacePlaceholders(
        characterFile.card.mesExample,
        charName: _charName,
        userName: session.personaName,
        localVariables: _localVariables,
        globalVariables: _globalVariables,
        trackingId: 'mesExample',
      );

      final wrapperCost = await UtilsLlm.countTokens(
        '<example_dialogue>\n\n</example_dialogue>',
      );
      final availableTokens = contextSize - _currentTokenCount;

      if (availableTokens > wrapperCost + _exampleWrapperSafetyMargin) {
        final contentBudget = availableTokens - wrapperCost;
        final exTokens = await UtilsLlm.countTokens(ex);

        if (exTokens > contentBudget) {
          final ratio = contentBudget / exTokens;
          final safeLength =
              (ex.length * ratio * _exampleTruncationRatioSafetyMargin).floor();
          if (safeLength <= 0) {
            ex = '';
          } else {
            ex =
                '${ex.substring(0, safeLength)}\n...[Example truncated for context limit]';
          }
        }

        if (ex.isNotEmpty) {
          final buffer = StringBuffer();
          _addSection(buffer, 'example_dialogue', ex);
          final examplesMsg = LlmRunnerMessage.system(buffer.toString().trim());

          final insertIndex = _messages.isNotEmpty ? 1 : 0;
          _messages.insert(insertIndex, examplesMsg);
          await _recordSegment(
            PromptSegmentKindEnum.exampleDialogue,
            examplesMsg.content,
          );
        }
      }
    }
  }

  void _assembleFinalMessages(List<LlmRunnerMessage> historyMessages) {
    _messages.addAll(historyMessages.reversed);

    if (_lcInjectedMsg != null) {
      _messages.add(_lcInjectedMsg!);
    }

    if (_postHistoryMsg != null) {
      _messages.add(_postHistoryMsg!);
    }

    if (_depthPromptMsg != null) {
      _depthInsertionMessages.add((
        msg: _depthPromptMsg!,
        depth: _depthPromptDepth,
      ));
    }

    _depthInsertionMessages.sort((a, b) => b.depth.compareTo(a.depth));

    for (final item in _depthInsertionMessages) {
      final minIndex = _messages.isNotEmpty ? 1 : 0;
      final index = (_messages.length - item.depth).clamp(
        minIndex,
        _messages.length,
      );
      _messages.insert(index, item.msg);
    }
  }
}
