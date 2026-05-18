import 'dart:math';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';

class EvaluatedLorebookEntry {
  const EvaluatedLorebookEntry({
    required this.entry,
    required this.content,
    required this.uidStr,
    this.decoratorOverrideDepth,
    this.decoratorOverrideRole,
  });
  final LorebookEntry entry;
  final String content;
  final String uidStr;
  final int? decoratorOverrideDepth;
  final ChatRoleEnum? decoratorOverrideRole;
}

class LorebookService {
  factory LorebookService() => _instance;
  LorebookService._internal();
  static final LorebookService _instance = LorebookService._internal();

  static const int _defaultScanDepth = 4;
  static const int _defaultInsertionOrder = 100;
  static const int _defaultProbability = 100;
  static const int _defaultSelectiveLogic = 0;
  static const int _maxProbability = 100;

  static final RegExp _jsRegexParser = RegExp(r'^/(.+)/([a-z]*)$');

  final Random _random = Random();
  final Map<String, RegExp> _regexCache = {};

  /// Evaluates a character's Lorebook against the current chat session context.
  List<EvaluatedLorebookEntry> evaluate(
    ChatSession session,
    CharacterFile characterFile,
  ) {
    final lorebook = characterFile.card.lorebook;
    if (lorebook == null || lorebook.entries.isEmpty) {
      return [];
    }

    final scanDepth = lorebook.scanDepth ?? _defaultScanDepth;
    final messageCount = session.messages.length;

    // 1. Build the searchable string from recent history
    final int startIndex = max(0, messageCount - scanDepth);
    final searchableString = session.messages
        .sublist(startIndex)
        .map((m) => m.content)
        .join('\n');

    final triggeredEntries = <EvaluatedLorebookEntry>[];

    // Clean up expired stickies and cooldowns
    session.activeStickies.removeWhere(
      (_, expireIndex) => messageCount >= expireIndex,
    );
    session.activeCooldowns.removeWhere(
      (_, expireIndex) => messageCount >= expireIndex,
    );

    // 2. Evaluate all entries
    for (
      var entryIndex = 0;
      entryIndex < lorebook.entries.length;
      entryIndex++
    ) {
      final entry = lorebook.entries[entryIndex];
      if (entry.enabled == false) continue;

      var content = entry.content ?? '';
      var forceActivate = false;
      var dontActivate = false;
      int? decoratorOverrideDepth;
      ChatRoleEnum? decoratorOverrideRole;

      var currentIndex = 0;
      var parsingDecorators = true;

      while (parsingDecorators && currentIndex < content.length) {
        var nextNewline = content.indexOf('\n', currentIndex);
        if (nextNewline == -1) nextNewline = content.length;

        final line = content.substring(currentIndex, nextNewline);
        final trimmed = line.trimLeft();

        if (trimmed.startsWith('@@')) {
          final firstSpace = trimmed.indexOf(' ');
          final cmd =
              (firstSpace != -1
                      ? trimmed.substring(2, firstSpace)
                      : trimmed.substring(2))
                  .replaceAll('@', '');
          if (cmd == 'activate') {
            forceActivate = true;
          } else if (cmd == 'dont_activate') {
            dontActivate = true;
          } else {
            final val = firstSpace != -1
                ? trimmed.substring(firstSpace + 1).trim()
                : '';
            if (cmd == 'depth' && decoratorOverrideDepth == null) {
              decoratorOverrideDepth = int.tryParse(val);
            } else if (cmd == 'role' && decoratorOverrideRole == null) {
              if (val == 'user') {
                decoratorOverrideRole = ChatRoleEnum.user;
              } else if (val == 'assistant') {
                decoratorOverrideRole = ChatRoleEnum.assistant;
              } else if (val == 'system') {
                decoratorOverrideRole = ChatRoleEnum.system;
              }
            }
          }
          currentIndex = nextNewline + 1;
        } else {
          parsingDecorators = false;
        }
      }

      if (currentIndex >= content.length) {
        content = '';
      } else if (currentIndex > 0) {
        content = content.substring(currentIndex).trim();
      } else {
        content = content.trim();
      }

      if (content.isEmpty) continue;

      final uidStr = entry.id?.toString() ?? entryIndex.toString();

      // Character Filter Evaluation
      if (entry.characterFilter != null) {
        final filter = entry.characterFilter!;
        var isFilteredOut = false;

        if (filter.names.isNotEmpty) {
          final nameMatch =
              filter.names.contains(characterFile.card.name) ||
              (characterFile.card.nickname?.isNotEmpty == true &&
                  filter.names.contains(characterFile.card.nickname));
          if (filter.isExclude ? nameMatch : !nameMatch) {
            isFilteredOut = true;
          }
        }

        if (!isFilteredOut && filter.tags.isNotEmpty) {
          final tagMatch = filter.tags.any(
            (t) => characterFile.card.tags.contains(t),
          );
          if (filter.isExclude ? tagMatch : !tagMatch) {
            isFilteredOut = true;
          }
        }

        if (isFilteredOut) {
          continue;
        }
      }

      if (dontActivate) continue;

      // Evaluate Timed Effects (Early Suppressor: Delay)
      final delay = entry.extensions.delay ?? 0;
      if (delay > 0 && messageCount < delay) continue;

      final isSticky = session.activeStickies.containsKey(uidStr);
      final isCooldown = session.activeCooldowns.containsKey(uidStr);

      // Cooldown blocks activation unless it was already sticky
      if (isCooldown && !isSticky) continue;

      var isTriggered = false;

      if (forceActivate || entry.constant == true || isSticky) {
        isTriggered = true;
      } else {
        isTriggered = _checkKeys(entry, searchableString);
      }

      if (isTriggered) {
        // Probability Check (Sticky bypasses probability)
        final probability = entry.extensions.probability ?? _defaultProbability;
        if (isSticky ||
            probability >= _maxProbability ||
            _random.nextInt(_maxProbability) < probability) {
          triggeredEntries.add(
            EvaluatedLorebookEntry(
              entry: entry,
              content: content,
              uidStr: uidStr,
              decoratorOverrideDepth: decoratorOverrideDepth,
              decoratorOverrideRole: decoratorOverrideRole,
            ),
          );
        }
      }
    }

    // 3. Sort for Token Budgeting
    // Priority: Constant entries first, then priority (CCv3), then insertionOrder.
    triggeredEntries.sort((a, b) {
      if (a.entry.constant == true && b.entry.constant != true) return -1;
      if (b.entry.constant == true && a.entry.constant != true) return 1;

      final prioA = a.entry.priority ?? 0;
      final prioB = b.entry.priority ?? 0;
      if (prioA != prioB) {
        return prioB.compareTo(prioA); // Highest priority first
      }

      return (a.entry.insertionOrder ?? _defaultInsertionOrder).compareTo(
        b.entry.insertionOrder ?? _defaultInsertionOrder,
      );
    });

    return triggeredEntries;
  }

  /// Applies timed effects (stickies, cooldowns) only to entries that survived the global context budget cuts.
  void commitTimedEffects(
    ChatSession session,
    List<EvaluatedLorebookEntry> survivors,
  ) {
    final messageCount = session.messages.length;
    final newStickies = <String, int>{};
    final newCooldowns = <String, int>{};

    for (final evaluated in survivors) {
      final uidStr = evaluated.uidStr;

      if (!session.activeStickies.containsKey(uidStr)) {
        final entry = evaluated.entry;
        final stickyLength = entry.extensions.sticky ?? 0;
        final cooldownLength = entry.extensions.cooldown ?? 0;

        if (stickyLength > 0) {
          newStickies[uidStr] = messageCount + stickyLength;
        }
        if (cooldownLength > 0) {
          newCooldowns[uidStr] = messageCount + stickyLength + cooldownLength;
        }
      }
    }
    session.activeStickies.addAll(newStickies);
    session.activeCooldowns.addAll(newCooldowns);
  }

  bool _checkKeys(LorebookEntry entry, String text) {
    if (entry.keys.isEmpty) return false;

    final caseSensitive =
        (entry.caseSensitive ?? entry.extensions.caseSensitive) == true;
    final matchWholeWords = entry.extensions.matchWholeWords == true;
    final haystackLower = text.toLowerCase();

    var hasPrimaryKey = false;
    for (final key in entry.keys) {
      if (_isMatch(
        key,
        text,
        haystackLower,
        entry.useRegex == true,
        caseSensitive,
        matchWholeWords,
      )) {
        hasPrimaryKey = true;
        break;
      }
    }

    if (!hasPrimaryKey) return false;

    // Selective filtering
    if (entry.selective == true && entry.secondaryKeys.isNotEmpty) {
      final selectiveLogic = entry.selectiveLogic ?? _defaultSelectiveLogic;
      var hasAnyMatch = false;
      var hasAllMatch = true;

      for (final key in entry.secondaryKeys) {
        if (_isMatch(
          key,
          text,
          haystackLower,
          entry.useRegex == true,
          caseSensitive,
          matchWholeWords,
        )) {
          hasAnyMatch = true;
        } else {
          hasAllMatch = false;
        }
      }

      if (selectiveLogic == 0 && !hasAnyMatch) return false; // AND ANY
      if (selectiveLogic == 3 && !hasAllMatch) return false; // AND ALL
      if (selectiveLogic == 2 && hasAnyMatch) return false; // NOT ANY
      if (selectiveLogic == 1 && hasAllMatch) return false; // NOT ALL
    }

    return true;
  }

  RegExp _getJsRegex(String key, bool defaultCaseSensitive) {
    final cacheKey = 'js_${defaultCaseSensitive}_$key';
    var regex = _regexCache[cacheKey];
    if (regex != null) return regex;

    if (_regexCache.length > 500) {
      _regexCache.clear();
    }

    var pattern = key;
    var isCase = defaultCaseSensitive;
    var isMultiLine = false;
    var isDotAll = false;
    var isUnicode = false;

    final match = _jsRegexParser.firstMatch(key);
    if (match != null) {
      // Group 1 is the (non-optional) pattern body of `/pattern/flags`.
      final body = match.group(1)!;
      pattern = body.replaceAll(r'\/', '/');
      final flags = match.group(2) ?? '';
      if (flags.contains('i')) isCase = false;
      if (flags.contains('m')) isMultiLine = true;
      if (flags.contains('s')) isDotAll = true;
      if (flags.contains('u')) isUnicode = true;
    }

    regex = RegExp(
      pattern,
      caseSensitive: isCase,
      multiLine: isMultiLine,
      dotAll: isDotAll,
      unicode: isUnicode,
    );
    _regexCache[cacheKey] = regex;
    return regex;
  }

  RegExp _getWordBoundaryRegex(String key, bool caseSensitive) {
    final cacheKey = 'wb_${caseSensitive}_$key';
    var regex = _regexCache[cacheKey];
    if (regex != null) return regex;

    if (_regexCache.length > 500) {
      _regexCache.clear();
    }

    final escapedKey = RegExp.escape(key);
    final pattern = r'(?:^|\W)' + escapedKey + r'(?:$|\W)';
    regex = RegExp(pattern, caseSensitive: caseSensitive);
    _regexCache[cacheKey] = regex;
    return regex;
  }

  bool _isMatch(
    String key,
    String text,
    String haystackLower,
    bool useRegex,
    bool caseSensitive,
    bool matchWholeWords,
  ) {
    if (key.isEmpty) return false;

    if (useRegex) {
      try {
        final regExp = _getJsRegex(key, caseSensitive);
        return regExp.hasMatch(text);
      } on Exception {
        // Invalid user-supplied regex. No log — this runs per keyword
        // per message; a bad pattern would flood logs without a
        // failure-cache. Treat as "no match" and move on.
        return false;
      }
    } else {
      if (matchWholeWords) {
        try {
          final regExp = _getWordBoundaryRegex(key, caseSensitive);
          return regExp.hasMatch(text);
        } on Exception {
          // Same rationale as the regex branch above — bad
          // word-boundary pattern from user. Silent on purpose.
          return false;
        }
      } else {
        final target = caseSensitive ? text : haystackLower;
        final needle = caseSensitive ? key : key.toLowerCase();
        return target.contains(needle);
      }
    }
  }
}
