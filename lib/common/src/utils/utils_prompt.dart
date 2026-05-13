import 'dart:math';
import 'package:intl/intl.dart';

class UtilsPrompt {
  static final _macroRegex = RegExp(r'\{\{([^{}]+)\}\}');
  static final _shorthandRegex = RegExp(
    r'^\s*([.$])([a-zA-Z0-9_-]+)\s*(\+\+|--|\+=|-=|\|\|=|\?\?=|\|\||\?\?|==|!=|>=|<=|>|<|=)?\s*(.*)$',
  );
  static final _random = Random();
  static final _timeFormatter = DateFormat.jm();
  static final _dateFormatter = DateFormat.yMMMMd();

  static String replacePlaceholders(
    String text, {
    required String charName,
    required String userName,
    Map<String, String>? localVariables,
    Map<String, String>? globalVariables,
    String? trackingId,
  }) {
    if (text.isEmpty || !text.contains('{{')) return text;

    var result = text;
    var changed = true;
    var safetyCounter = 0;
    var pickCounter = 0;

    while (changed && safetyCounter < 100) {
      changed = false;
      safetyCounter++;
      result = result.replaceAllMapped(_macroRegex, (match) {
        final original = match.group(0)!;
        final innerContent = match.group(1)!;
        final evaluation = _evaluateMacro(
          innerContent,
          charName,
          userName,
          localVariables,
          globalVariables,
          trackingId,
          () => pickCounter++,
        );

        if (evaluation != original) {
          changed = true;
        }
        return evaluation;
      });
    }

    return result;
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

    // Fast-fail regex matching for variables by checking prefix
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

    bool isTruthy(String? v) {
      if (v == null || v.trim().isEmpty) return false;
      final lower = v.trim().toLowerCase();
      if (lower == 'false' || lower == '0' || lower == 'off' || lower == 'no') {
        return false;
      }
      return true;
    }

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
        return isTruthy(currentVal) ? (currentVal ?? '') : value;
      case '??':
        return currentVal ?? value;
      case '||=':
        if (!isTruthy(currentVal)) {
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
