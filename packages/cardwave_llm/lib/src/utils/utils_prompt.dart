import 'dart:math';
import 'package:intl/intl.dart';

/// SillyTavern-compatible `{{...}}` placeholder substitution engine. Resolves
/// `{{char}}`, `{{user}}`, `{{getvar::x}}`, `{{$globalvar}}`, `{{if}}` blocks,
/// etc. in a single left-to-right pass, so a variable written on the left is
/// visible to a read on the right and an `{{if}}`'s dropped branch never runs.
/// Single source of truth: the app re-exports this class through
/// `lib/common/common.dart`. See `utils_prompt.md` for the full macro list.
class UtilsPrompt {
  static final _shorthandRegex = RegExp(
    r'^\s*([.$])([a-zA-Z0-9_]+)\s*(\+\+|--|\+=|-=|\|\|=|\?\?=|\|\||\?\?|==|!=|>=|<=|>|<|=)?\s*(.*)$',
  );
  static final _random = Random();
  static final _timeFormatter = DateFormat.jm();
  static final _dateFormatter = DateFormat.yMMMMd();
  static final _utcTimeRegex = RegExp(
    r'^time\s*(?:::?|_)\s*utc\s*([+-]\d+)\s*$',
    caseSensitive: false,
  );
  static final _ifHeadRegex = RegExp(r'^\s*if\b', caseSensitive: false);
  static final _trimTagRegex = RegExp(
    r'\{\{\s*(/)?\s*trim\s*\}\}',
    caseSensitive: false,
  );
  static final _condTagRegex = RegExp(
    r'\{\{\s*(?:(if)\b|(else)\s*\}\}|/\s*if\s*\}\})',
    caseSensitive: false,
  );

  /// Bounds re-expansion of a macro's *returned* value (e.g. a variable whose
  /// stored value is itself `{{char}}`) so variables that reference each other
  /// in a cycle terminate instead of recursing forever.
  static const _maxValueExpansionDepth = 50;

  static String replacePlaceholders(
    String text, {
    required String charName,
    required String userName,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
    String? trackingId,
  }) {
    if (text.isEmpty || !text.contains('{{')) return text;

    var pickCounter = 0;
    return _render(
      text,
      charName,
      userName,
      localVariables,
      globalVariables,
      trackingId,
      () => pickCounter++,
      0,
    );
  }

  /// One left-to-right pass over [text]. At each `{{` the matching `}}` is found
  /// via [_matchingClose]; nested macros resolve first, then this macro is
  /// applied — mutating the shared variable maps in place — before the walk
  /// advances past it, so a write on the left lands before a read on the right.
  /// `{{if}}…{{else}}…{{/if}}` is recognised as a block: only the kept branch is
  /// rendered, so a side-effecting macro in the dropped branch never runs.
  /// [depth] bounds re-expansion of returned values (see
  /// [_maxValueExpansionDepth]).
  static String _render(
    String text,
    String charName,
    String userName,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
    String? trackingId,
    int Function() nextPickIndex,
    int depth,
  ) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (text[i] != '{' || i + 1 >= text.length || text[i + 1] != '{') {
        buffer.write(text[i]);
        i++;
        continue;
      }

      final close = _matchingClose(text, i);
      if (close == -1) {
        buffer.write(text.substring(i)); // unbalanced — leak the rest verbatim
        break;
      }
      final inner = text.substring(i + 2, close);

      final ifHead = _ifHeadRegex.firstMatch(inner);
      if (ifHead != null) {
        i = _renderConditional(
          text,
          i,
          close,
          inner.substring(ifHead.end),
          buffer,
          charName,
          userName,
          localVariables,
          globalVariables,
          trackingId,
          nextPickIndex,
          depth,
        );
        continue;
      }

      final resolvedInner = inner.contains('{{')
          ? _render(
              inner,
              charName,
              userName,
              localVariables,
              globalVariables,
              trackingId,
              nextPickIndex,
              depth,
            )
          : inner;

      // {{trim}}...{{/trim}}: renders the block, strips all surrounding
      // whitespace from the result. Standalone {{trim}} (no closing tag) leaks
      // verbatim via the _evaluateMacro default branch below.
      if (resolvedInner.trim().toLowerCase() == 'trim') {
        final bodyStart = close + 2;
        var blockDepth = 1;
        var endStart = -1;
        var endEnd = -1;
        for (final tag in _trimTagRegex.allMatches(text, bodyStart)) {
          if (tag.group(1) != null) {
            blockDepth--;
            if (blockDepth == 0) {
              endStart = tag.start;
              endEnd = tag.end;
              break;
            }
          } else {
            blockDepth++;
          }
        }
        if (endStart != -1) {
          buffer.write(
            _render(
              text.substring(bodyStart, endStart),
              charName,
              userName,
              localVariables,
              globalVariables,
              trackingId,
              nextPickIndex,
              depth,
            ).trim(),
          );
          i = endEnd;
          continue;
        }
      }

      final value = _evaluateMacro(
        resolvedInner,
        charName,
        userName,
        localVariables,
        globalVariables,
        trackingId,
        nextPickIndex,
      );

      // A returned value that itself contains a macro (e.g. a variable storing
      // `{{char}}`) is expanded once more; a value identical to its own source
      // (unknown macro, self-referential getvar) is left as-is to terminate.
      final source = text.substring(i, close + 2);
      if (value != source &&
          value.contains('{{') &&
          depth < _maxValueExpansionDepth) {
        buffer.write(
          _render(
            value,
            charName,
            userName,
            localVariables,
            globalVariables,
            trackingId,
            nextPickIndex,
            depth + 1,
          ),
        );
      } else {
        buffer.write(value);
      }
      i = close + 2;
    }
    return buffer.toString();
  }

  /// Renders an `{{if}}` block whose opening tag starts at [openStart] and whose
  /// tag closes at [tagClose]. Finds the matching `{{else}}` / `{{/if}}`
  /// (honouring nested `{{if}}`s), evaluates [condition], renders only the kept
  /// branch into [buffer], and returns the index just past `{{/if}}` — or past
  /// the `{{if}}` tag when the block is unbalanced, leaking the tag verbatim.
  static int _renderConditional(
    String text,
    int openStart,
    int tagClose,
    String condition,
    StringBuffer buffer,
    String charName,
    String userName,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
    String? trackingId,
    int Function() nextPickIndex,
    int depth,
  ) {
    final bodyStart = tagClose + 2;
    var blockDepth = 1;
    var elseStart = -1;
    var elseEnd = -1;
    var endStart = -1;
    var endEnd = -1;
    for (final tag in _condTagRegex.allMatches(text, bodyStart)) {
      if (tag.group(1) != null) {
        blockDepth++;
      } else if (tag.group(2) != null) {
        if (blockDepth == 1 && elseStart == -1) {
          elseStart = tag.start;
          elseEnd = tag.end;
        }
      } else {
        blockDepth--;
        if (blockDepth == 0) {
          endStart = tag.start;
          endEnd = tag.end;
          break;
        }
      }
    }
    if (endStart == -1) {
      buffer.write(text.substring(openStart, bodyStart)); // unbalanced
      return bodyStart;
    }

    final taken = _evaluateCondition(
      condition,
      charName,
      userName,
      localVariables,
      globalVariables,
      trackingId,
      nextPickIndex,
      depth,
    );
    final String branch;
    if (elseStart != -1) {
      branch = taken
          ? text.substring(bodyStart, elseStart)
          : text.substring(elseEnd, endStart);
    } else {
      branch = taken ? text.substring(bodyStart, endStart) : '';
    }
    buffer.write(
      _render(
        branch,
        charName,
        userName,
        localVariables,
        globalVariables,
        trackingId,
        nextPickIndex,
        depth,
      ),
    );
    return endEnd;
  }

  static String _evaluateMacro(
    String innerContent,
    String charName,
    String userName,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
    String? trackingId,
    int Function() nextPickIndex,
  ) {
    final trimmed = innerContent.trimLeft();
    if (trimmed.startsWith('//')) {
      return '';
    }

    if (trimmed.startsWith('.') || trimmed.startsWith(r'$')) {
      final shorthandMatch = _shorthandRegex.firstMatch(trimmed);
      if (shorthandMatch != null) {
        return _evaluateShorthand(
          shorthandMatch,
          localVariables,
          globalVariables,
        );
      }
    }

    final utcTime = _utcTimeOrNull(trimmed);
    if (utcTime != null) return utcTime;

    String command;
    var argStr = '';
    var usedDoubleColon = false;

    var sepIndex = trimmed.indexOf('::');
    if (sepIndex != -1) {
      command = trimmed.substring(0, sepIndex).toLowerCase();
      argStr = trimmed.substring(sepIndex + 2).trim();
      usedDoubleColon = true;
    } else {
      sepIndex = trimmed.indexOf(':');
      if (sepIndex != -1) {
        command = trimmed.substring(0, sepIndex).toLowerCase();
        argStr = trimmed.substring(sepIndex + 1).trim();
      } else {
        sepIndex = trimmed.indexOf(' ');
        if (sepIndex != -1) {
          command = trimmed.substring(0, sepIndex).toLowerCase();
          argStr = trimmed.substring(sepIndex + 1).trim();
        } else {
          command = trimmed.toLowerCase();
        }
      }
    }

    switch (command) {
      case 'char':
      case 'bot':
        return charName.trim();
      case 'user':
        return userName.trim();
      case 'time':
        return _timeFormatter.format(DateTime.now());
      case 'date':
        return _dateFormatter.format(DateTime.now());
      case 'random':
      case 'pick':
        if (argStr.isEmpty) return '';
        List<String> rawOptions;
        if (usedDoubleColon) {
          rawOptions = argStr.split('::');
        } else if (argStr.contains(',')) {
          rawOptions = argStr.split(',');
        } else {
          rawOptions = [argStr];
        }

        final options = <String>[];
        for (final opt in rawOptions) {
          final t = opt.trim();
          if (t.isNotEmpty) options.add(t);
        }
        if (options.isEmpty) return '';

        if (command == 'random') {
          return options[_random.nextInt(options.length)];
        }
        if (localVariables == null || trackingId == null) {
          return options[_random.nextInt(options.length)];
        }
        final pickIndex = nextPickIndex();
        final key = '__sys_pick_${trackingId}_$pickIndex';
        if (localVariables.containsKey(key)) {
          final savedValue = localVariables[key]!;
          if (options.contains(savedValue)) {
            return savedValue;
          }
        }
        final pickedValue = options[_random.nextInt(options.length)];
        localVariables[key] = pickedValue;
        return pickedValue;
      case 'roll':
        if (argStr.isEmpty) return '';
        final rollStr = argStr.toLowerCase();
        final dIndex = rollStr.indexOf('d');
        if (dIndex != -1) {
          var count = int.tryParse(rollStr.substring(0, dIndex)) ?? 1;
          if (count > 100) count = 100;
          var faces = int.tryParse(rollStr.substring(dIndex + 1)) ?? 20;
          if (faces < 1) faces = 1;
          var total = 0;
          for (var i = 0; i < count; i++) {
            total += _random.nextInt(faces) + 1;
          }
          return total.toString();
        }
        var max = int.tryParse(rollStr) ?? 20;
        if (max < 1) max = 1;
        return (_random.nextInt(max) + 1).toString();
      case 'getvar':
        if (argStr.isEmpty || localVariables == null) return '';
        return localVariables[usedDoubleColon
                ? argStr.split('::').first.trim()
                : argStr] ??
            '';
      case 'setvar':
        if (argStr.isEmpty || localVariables == null) return '';
        if (usedDoubleColon) {
          final firstD = argStr.indexOf('::');
          if (firstD != -1) {
            localVariables[argStr.substring(0, firstD).trim()] = argStr
                .substring(firstD + 2)
                .trim();
          } else {
            localVariables[argStr] = '';
          }
        } else {
          var sIdx = argStr.indexOf(' ');
          if (sIdx == -1) sIdx = argStr.indexOf(':');
          if (sIdx != -1) {
            localVariables[argStr.substring(0, sIdx).trim()] = argStr
                .substring(sIdx + 1)
                .trim();
          }
        }
        return '';
      case 'getglobalvar':
        if (argStr.isEmpty || globalVariables == null) return '';
        return globalVariables[usedDoubleColon
                ? argStr.split('::').first.trim()
                : argStr] ??
            '';
      case 'setglobalvar':
        if (argStr.isEmpty || globalVariables == null) return '';
        if (usedDoubleColon) {
          final firstD = argStr.indexOf('::');
          if (firstD != -1) {
            globalVariables[argStr.substring(0, firstD).trim()] = argStr
                .substring(firstD + 2)
                .trim();
          } else {
            globalVariables[argStr] = '';
          }
        } else {
          var sIdx = argStr.indexOf(' ');
          if (sIdx == -1) sIdx = argStr.indexOf(':');
          if (sIdx != -1) {
            globalVariables[argStr.substring(0, sIdx).trim()] = argStr
                .substring(sIdx + 1)
                .trim();
          }
        }
        return '';
      case 'newline':
        if (argStr.isNotEmpty) {
          final count = int.tryParse(argStr) ?? 1;
          return '\n' * count.clamp(1, 100);
        }
        return '\n';
      case 'space':
        if (argStr.isNotEmpty) {
          final count = int.tryParse(argStr) ?? 1;
          return ' ' * count.clamp(1, 100);
        }
        return ' ';
      case 'noop':
      case 'hidden_key':
      case 'comment':
        return '';
      case 'reverse':
        if (argStr.isEmpty) return '';
        return argStr.split('').reversed.join();
      default:
        return '{{$innerContent}}';
    }
  }

  /// Resolves SillyTavern's UTC-offset time macro — `{{time_UTC±H}}` (the form
  /// real cards use) and the documented `{{time::UTC±H}}` — to the current time
  /// at that whole-hour offset. Returns null when [trimmed] is not such a macro.
  static String? _utcTimeOrNull(String trimmed) {
    final match = _utcTimeRegex.firstMatch(trimmed);
    if (match == null) return null;
    final shifted = DateTime.now().toUtc().add(
      Duration(hours: int.parse(match.group(1)!)),
    );
    return _timeFormatter.format(shifted);
  }

  /// Index of the `}}` that closes the `{{` at [openIndex], honouring nested
  /// braces, or -1 if unbalanced.
  static int _matchingClose(String text, int openIndex) {
    var depth = 0;
    var i = openIndex;
    while (i < text.length - 1) {
      if (text[i] == '{' && text[i + 1] == '{') {
        depth++;
        i += 2;
      } else if (text[i] == '}' && text[i + 1] == '}') {
        depth--;
        i += 2;
        if (depth == 0) return i - 2;
      } else {
        i++;
      }
    }
    return -1;
  }

  /// Evaluates an `{{if}}` condition for truthiness. Shorthand (`.x`/`$x`) and
  /// any nested macro are resolved through the engine; a plain literal is tested
  /// directly. Leading `!` inverts.
  static bool _evaluateCondition(
    String condition,
    String charName,
    String userName,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
    String? trackingId,
    int Function() nextPickIndex,
    int depth,
  ) {
    var cond = condition.trim();
    var inverted = false;
    while (cond.startsWith('!')) {
      inverted = !inverted;
      cond = cond.substring(1).trim();
    }
    if (cond.isEmpty) return inverted;

    final bool truthy;
    if (cond.startsWith('.') || cond.startsWith(r'$') || cond.contains('{{')) {
      final wrapped = cond.contains('{{') ? cond : '{{$cond}}';
      truthy = _isTruthy(
        _render(
          wrapped,
          charName,
          userName,
          localVariables,
          globalVariables,
          trackingId,
          nextPickIndex,
          depth,
        ),
      );
    } else {
      truthy = _isTruthy(cond);
    }
    return inverted ? !truthy : truthy;
  }

  static bool _isTruthy(String? value) {
    if (value == null) return false;
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (lower == 'false' || lower == '0' || lower == 'off' || lower == 'no') {
      return false;
    }
    return true;
  }

  static String _evaluateShorthand(
    Match match,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
  ) {
    final scope = match.group(1)!;
    final varName = match.group(2)!;
    final operator = match.group(3) ?? '';
    final value = (match.group(4) ?? '').trim();

    final isGlobal = scope == r'$';
    final varMap = isGlobal ? globalVariables : localVariables;

    if (varMap == null) return '';

    final currentVal = varMap[varName];

    String formatNum(num n) =>
        n == n.toInt() ? n.toInt().toString() : n.toString();

    switch (operator) {
      case '':
        return currentVal ?? '';
      case '=':
        varMap[varName] = value;
        return '';
      case '++':
        final n = (num.tryParse(currentVal ?? '') ?? 0) + 1;
        final res = formatNum(n);
        varMap[varName] = res;
        return res;
      case '--':
        final n = (num.tryParse(currentVal ?? '') ?? 0) - 1;
        final res = formatNum(n);
        varMap[varName] = res;
        return res;
      case '+=':
        final currentNum = num.tryParse(currentVal ?? '');
        final valNum = num.tryParse(value);
        if (currentNum != null && valNum != null) {
          varMap[varName] = formatNum(currentNum + valNum);
        } else {
          varMap[varName] = (currentVal ?? '') + value;
        }
        return '';
      case '-=':
        final currentNum = num.tryParse(currentVal ?? '');
        final valNum = num.tryParse(value);
        if (currentNum != null && valNum != null) {
          varMap[varName] = formatNum(currentNum - valNum);
        }
        return '';
      case '||':
        return _isTruthy(currentVal) ? (currentVal ?? '') : value;
      case '??':
        return currentVal ?? value;
      case '||=':
        if (!_isTruthy(currentVal)) {
          varMap[varName] = value;
        }
        return varMap[varName] ?? '';
      case '??=':
        if (currentVal == null) {
          varMap[varName] = value;
        }
        return varMap[varName] ?? '';
      case '==':
        return (currentVal ?? '') == value ? 'true' : 'false';
      case '!=':
        return (currentVal ?? '') != value ? 'true' : 'false';
      case '>':
      case '>=':
      case '<':
      case '<=':
        final cn = num.tryParse(currentVal ?? '');
        final vn = num.tryParse(value);
        if (cn == null || vn == null) return 'false';
        if (operator == '>') return cn > vn ? 'true' : 'false';
        if (operator == '>=') return cn >= vn ? 'true' : 'false';
        if (operator == '<') return cn < vn ? 'true' : 'false';
        return cn <= vn ? 'true' : 'false';
      default:
        return '';
    }
  }
}
