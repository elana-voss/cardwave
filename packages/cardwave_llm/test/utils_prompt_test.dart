import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';

/// Convenience wrapper around the engine with sensible defaults.
String render(
  String text, {
  String char = 'Cass',
  String user = 'User',
  Map<String, String>? local,
  Map<String, String>? global,
  String? trackingId,
}) {
  return UtilsPrompt.replacePlaceholders(
    text,
    charName: char,
    userName: user,
    localVariables: local,
    globalVariables: global,
    trackingId: trackingId,
  );
}

void main() {
  group('identity and passthrough', () {
    test('empty / brace-free text is returned unchanged', () {
      expect(render(''), '');
      expect(render('plain text, no macros'), 'plain text, no macros');
    });

    test('{{char}} / {{bot}} / {{user}} substitute and trim', () {
      expect(render('{{char}}'), 'Cass');
      expect(render('{{bot}}'), 'Cass');
      expect(render('{{user}}'), 'User');
      expect(render('{{char}}', char: '  Cass  '), 'Cass');
      expect(render('Hi {{user}}, I am {{char}}.'), 'Hi User, I am Cass.');
    });

    test('unknown macros leak verbatim', () {
      expect(render('{{description}}'), '{{description}}');
      expect(render('a {{trim}} b'), 'a {{trim}} b');
      expect(render('{{incvar::x}}'), '{{incvar::x}}');
    });
  });

  group('comments and whitespace macros', () {
    test('comment forms emit nothing', () {
      expect(render('{{// hidden note}}'), '');
      expect(render('{{noop}}'), '');
      expect(render('{{hidden_key}}'), '');
      expect(render('{{comment}}'), '');
      expect(render('a{{// x}}b'), 'ab');
    });

    test('newline and space, with and without counts', () {
      expect(render('{{newline}}'), '\n');
      expect(render('{{newline::3}}'), '\n\n\n');
      expect(render('{{space}}'), ' ');
      expect(render('{{space::4}}'), '    ');
    });

    test('newline / space counts clamp to 1..100', () {
      expect(render('{{newline::0}}'), '\n');
      expect(render('{{space::0}}'), ' ');
      expect(render('{{newline::500}}').length, 100);
    });

    test('reverse', () {
      expect(render('{{reverse::abc}}'), 'cba');
      expect(render('{{reverse::}}'), '');
    });
  });

  group('roll', () {
    test('deterministic single-face dice', () {
      expect(render('{{roll::1d1}}'), '1');
      expect(render('{{roll::10d1}}'), '10');
    });

    test('count is capped at 100', () {
      expect(render('{{roll::150d1}}'), '100');
    });

    test('flat and NdF rolls stay within range', () {
      for (var i = 0; i < 200; i++) {
        final flat = int.parse(render('{{roll::6}}'));
        expect(flat, inInclusiveRange(1, 6));
        final dice = int.parse(render('{{roll::2d6}}'));
        expect(dice, inInclusiveRange(2, 12));
      }
    });

    test('single colon form parses', () {
      expect(render('{{roll:1d1}}'), '1');
    });
  });

  group('random and pick', () {
    test('single option is deterministic', () {
      expect(render('{{random::only}}'), 'only');
      expect(render('{{random::a::a}}'), 'a');
    });

    test('random returns a member of the list', () {
      for (var i = 0; i < 100; i++) {
        expect(['a', 'b', 'c'], contains(render('{{random::a::b::c}}')));
      }
    });

    test('comma list in single-colon form', () {
      for (var i = 0; i < 50; i++) {
        expect(['x', 'y'], contains(render('{{random:x,y}}')));
      }
    });

    test('pick is stable across renders with same map + trackingId', () {
      final local = <String, String>{};
      final first = render(
        '{{pick::a::b::c::d::e}}',
        local: local,
        trackingId: 'chat1',
      );
      for (var i = 0; i < 20; i++) {
        final again = render(
          '{{pick::a::b::c::d::e}}',
          local: local,
          trackingId: 'chat1',
        );
        expect(again, first);
      }
      expect(local.keys, contains('__sys_pick_chat1_0'));
    });

    test('pick falls back to random without trackingId / map', () {
      for (var i = 0; i < 50; i++) {
        expect(['a', 'b'], contains(render('{{pick::a::b}}')));
      }
    });
  });

  group('local and global variables (named forms)', () {
    test('setvar / getvar via double colon', () {
      final local = <String, String>{};
      expect(render('{{setvar::name::Alice}}', local: local), '');
      expect(render('{{getvar::name}}', local: local), 'Alice');
    });

    test('getvar of an unset name is empty', () {
      expect(render('{{getvar::missing}}', local: {}), '');
    });

    test('setvar single-colon and space forms', () {
      final c = <String, String>{};
      render('{{setvar:k:v}}', local: c);
      expect(render('{{getvar::k}}', local: c), 'v');
      final s = <String, String>{};
      render('{{setvar k v}}', local: s);
      expect(render('{{getvar::k}}', local: s), 'v');
    });

    test('global setglobalvar / getglobalvar', () {
      final g = <String, String>{};
      render('{{setglobalvar::g::42}}', global: g);
      expect(render('{{getglobalvar::g}}', global: g), '42');
    });

    test('value may contain a double colon', () {
      final c = <String, String>{};
      render('{{setvar::k::a::b}}', local: c);
      expect(render('{{getvar::k}}', local: c), 'a::b');
    });
  });

  group('variable shorthand', () {
    test('read, set, and the dollar/dot scopes', () {
      final local = <String, String>{};
      final global = <String, String>{};
      expect(render('{{.x = 5}}', local: local), '');
      expect(render('{{.x}}', local: local), '5');
      render(r'{{$g = hi}}', global: global);
      expect(render(r'{{$g}}', global: global), 'hi');
    });

    test('increment / decrement default to 0 and emit the new value', () {
      final c = <String, String>{};
      expect(render('{{.n++}}', local: c), '1');
      expect(render('{{.n++}}', local: c), '2');
      expect(render('{{.n--}}', local: c), '1');
    });

    test('numeric += and -=', () {
      final c = <String, String>{'n': '10'};
      render('{{.n += 5}}', local: c);
      expect(c['n'], '15');
      render('{{.n -= 3}}', local: c);
      expect(c['n'], '12');
    });

    test('+= appends when either side is non-numeric', () {
      final c = <String, String>{'s': 'ab'};
      render('{{.s += cd}}', local: c);
      expect(c['s'], 'abcd');
    });

    test('|| uses fallback when falsy, ?? only when unset', () {
      expect(render('{{.x || fb}}', local: {'x': '0'}), 'fb');
      expect(render('{{.x || fb}}', local: {'x': 'val'}), 'val');
      expect(render('{{.x ?? fb}}', local: {}), 'fb');
      expect(render('{{.x ?? fb}}', local: {'x': ''}), '');
    });

    test('||= and ??= assignment semantics', () {
      final a = <String, String>{'x': ''};
      expect(render('{{.x ||= set}}', local: a), 'set');
      final b = <String, String>{'x': 'keep'};
      expect(render('{{.x ??= other}}', local: b), 'keep');
    });

    test('equality and numeric comparisons', () {
      final c = <String, String>{'x': '5'};
      expect(render('{{.x == 5}}', local: c), 'true');
      expect(render('{{.x != 5}}', local: c), 'false');
      expect(render('{{.x > 3}}', local: c), 'true');
      expect(render('{{.x <= 5}}', local: c), 'true');
      expect(render('{{.x < 3}}', local: c), 'false');
      expect(render('{{.word > 3}}', local: {'word': 'abc'}), 'false');
    });
  });

  group('nested resolution', () {
    test('a stored value containing a macro expands when read', () {
      expect(render('{{getvar::x}}', local: {'x': '{{char}}'}), 'Cass');
    });

    test('plain setvar then getvar in the same text', () {
      expect(render('{{setvar::x::5}}{{getvar::x}}', local: {}), '5');
    });

    test('self-referential variable terminates without hanging', () {
      expect(
        render('{{getvar::x}}', local: {'x': '{{getvar::x}}'}),
        '{{getvar::x}}',
      );
    });
  });

  group('time', () {
    test('{{time}} / {{date}} resolve to non-empty, non-literal text', () {
      final t = render('{{time}}');
      expect(t, isNotEmpty);
      expect(t.contains('{{'), isFalse);
      expect(render('{{date}}').contains('{{'), isFalse);
    });

    test('UTC offset forms resolve and differ across offsets', () {
      expect(render('{{time_UTC+0}}').contains('{{'), isFalse);
      expect(render('{{time::UTC+0}}').contains('{{'), isFalse);
      expect(render('{{time_UTC+3}}'), isNot(render('{{time_UTC-3}}')));
    });

    test('malformed UTC offset leaks', () {
      expect(render('{{time_UTC+abc}}').contains('{{'), isTrue);
    });
  });

  group('conditionals', () {
    test('basic then / else with shorthand condition', () {
      expect(render('{{if .v}}Y{{else}}N{{/if}}', local: {'v': '1'}), 'Y');
      expect(render('{{if .v}}Y{{else}}N{{/if}}', local: {}), 'N');
    });

    test('no else branch drops to empty when false', () {
      expect(render('{{if .v}}Y{{/if}}', local: {}), '');
      expect(render('{{if .v}}Y{{/if}}', local: {'v': 'on'}), 'Y');
    });

    test('! inverts the condition', () {
      expect(render('{{if !.flag}}X{{/if}}', local: {}), 'X');
      expect(render('{{if !.flag}}X{{/if}}', local: {'flag': '1'}), '');
    });

    test('zero literal is falsy, not a leaked brace', () {
      expect(render('{{if 0}}x{{/if}}'), '');
      expect(render('{{if 1}}x{{/if}}'), 'x');
    });

    test('nested blocks', () {
      const tpl = '{{if .a}}A{{if .b}}B{{/if}}{{/if}}';
      expect(render(tpl, local: {'a': '1', 'b': '1'}), 'AB');
      expect(render(tpl, local: {'a': '1'}), 'A');
      expect(render(tpl, local: {}), '');
    });

    test('condition through a nested getvar macro', () {
      expect(
        render('{{if {{getvar::flag}}}}yes{{/if}}', local: {'flag': '1'}),
        'yes',
      );
      expect(
        render('{{if {{getvar::flag}}}}yes{{/if}}', local: {'flag': '0'}),
        '',
      );
    });

    test('comparison condition', () {
      expect(
        render(
          '{{setvar::score::5}}{{if .score > 3}}high{{else}}low{{/if}}',
          local: {},
        ),
        'high',
      );
      expect(
        render(
          '{{setvar::score::2}}{{if .score > 3}}high{{else}}low{{/if}}',
          local: {},
        ),
        'low',
      );
    });

    test('lenient spacing and multi-line block', () {
      expect(render('{{ if .v }}Y{{ /if }}', local: {'v': '1'}), 'Y');
      const multi = '{{if .v}}\nline one\nline two\n{{/if}}';
      expect(render(multi, local: {'v': '1'}), '\nline one\nline two\n');
    });

    test('a variable set before the block affects the condition', () {
      expect(render('{{setvar::x::1}}{{if .x}}set{{/if}}', local: {}), 'set');
    });

    test('unbalanced block leaks unchanged', () {
      expect(render('{{if .a}}hello', local: {'a': '1'}), '{{if .a}}hello');
    });

    // The dropped branch is never rendered, so its setvar never runs: y keeps
    // the value the taken branch set.
    test('side effects in the dropped branch do not run', () {
      expect(
        render(
          '{{if .a}}{{setvar::y::1}}{{else}}{{setvar::y::2}}{{/if}}{{getvar::y}}',
          local: {'a': '1'},
        ),
        '1',
      );
    });
  });

  group('single-pass ordering', () {
    test('a variable assigned a macro value is readable later in the text', () {
      expect(
        render('{{setvar::x::{{char}}}}[{{getvar::x}}]', local: {}),
        '[Cass]',
      );
    });

    test('shorthand assigned a macro value is readable later in the text', () {
      final local = <String, String>{};
      expect(render('{{.who = {{char}}}}[{{.who}}]', local: local), '[Cass]');
      expect(local['who'], 'Cass');
    });

    test('a variable assigned from a nested pick is readable later', () {
      final local = <String, String>{};
      final out = render(
        '{{.region = {{pick::tono::iya::kiso}}}}[{{.region}}]',
        local: local,
        trackingId: 'chat1',
      );
      final picked = local['region']!;
      expect(['tono', 'iya', 'kiso'], contains(picked));
      expect(out, '[$picked]');
    });

    test('if reads a variable assigned from a pick earlier in the text', () {
      expect(
        render(
          '{{.region = {{pick::tono}}}}'
          '{{if {{.region == tono}}}}repair{{else}}none{{/if}}',
          local: {},
          trackingId: 't',
        ),
        'repair',
      );
    });
  });

  // A full card-style template: a hidden setup block assigns variables from
  // nested picks, then later prose reads those variables and branches on them.
  group('full template processing', () {
    const template = '''<!--
{{.mode = alpha}}
{{.region = {{pick::north::south::east}}}}
{{.delay = {{pick::one day::two days::three days, maybe four}}}}
{{.notified = {{pick::yes::no}}}}
Setup notes: The delay is {{.delay}}. {{if {{.notified == yes}} }}The office already knows.{{else}}The office does not know yet.{{/if}} Decide nothing for them.
-->

Dummy opening paragraph one. Dummy opening paragraph two.

Dummy narration mentioning the delay of {{.delay}} and the situation at hand.

{{if {{.region == north}} }}Northern branch: a place in the north.{{/if}}{{if {{.region == south}} }}Southern branch: a place in the south.{{/if}}{{if {{.region == east}} }}Eastern branch: a place in the east.{{/if}}

Dummy closing line.''';

    const regionBranches = {
      'north': 'Northern branch: a place in the north.',
      'south': 'Southern branch: a place in the south.',
      'east': 'Eastern branch: a place in the east.',
    };

    test('assigns from nested picks, then reads and branches on them', () {
      final local = <String, String>{};
      final out = render(template, local: local, trackingId: 'run1');

      // Each assignment captured a member of its own pick list.
      expect(local['mode'], 'alpha');
      expect(['north', 'south', 'east'], contains(local['region']));
      expect(
        ['one day', 'two days', 'three days, maybe four'],
        contains(local['delay']),
      );
      expect(['yes', 'no'], contains(local['notified']));

      // Every macro resolved; no braces leaked into the output.
      expect(out.contains('{{'), isFalse);

      // Both {{.delay}} reads return the stored value.
      final delay = local['delay']!;
      expect(out, contains('The delay is $delay.'));
      expect(out, contains('delay of $delay'));

      // The notified conditional rendered the branch matching the pick.
      if (local['notified'] == 'yes') {
        expect(out, contains('The office already knows.'));
        expect(out, isNot(contains('The office does not know yet.')));
      } else {
        expect(out, contains('The office does not know yet.'));
        expect(out, isNot(contains('The office already knows.')));
      }

      // Exactly one region branch rendered, matching .region.
      final region = local['region']!;
      expect(out, contains(regionBranches[region]));
      for (final other in regionBranches.keys.where((k) => k != region)) {
        expect(out, isNot(contains(regionBranches[other])));
      }
    });

    test('renders identically across passes with the same map + trackingId',
        () {
      final local = <String, String>{};
      final first = render(template, local: local, trackingId: 'run1');
      for (var i = 0; i < 20; i++) {
        expect(render(template, local: local, trackingId: 'run1'), first);
      }
    });
  });
}
