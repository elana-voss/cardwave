import 'package:cardwave/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UtilsAppTextTrim.trim', () {
    test('leaves a reply that already ends cleanly', () {
      const text = 'I hear you. What would you like to do next?';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('drops an incomplete trailing sentence', () {
      const text =
          'I understand completely, and I want to help you with that. '
          'But please don\'t feel pressured if you would rather not';
      expect(
        UtilsAppTextTrim.trim(text),
        'I understand completely, and I want to help you with that.',
      );
    });

    test('keeps the original when the trim removes too much', () {
      // Only a short clean head, then a long unfinished tail — trimming
      // would drop below the keep threshold, so the original survives.
      const text = 'Okay. And then we set off down the long winding road '
          'toward the distant glittering city that nobody had ever';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('never returns empty when no boundary exists', () {
      const text = 'What kind of information are you looking for right now';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('does not treat an abbreviation dot as a sentence end', () {
      const text = 'I already told you that it was perfectly fine. Now go '
          'and see Dr. Hartley about it because she';
      expect(
        UtilsAppTextTrim.trim(text),
        'I already told you that it was perfectly fine.',
      );
    });

    test('does not treat a decimal point as a sentence end', () {
      const text = 'It had always been exactly like that. The reading held '
          'at 3.5 right up until it';
      expect(
        UtilsAppTextTrim.trim(text),
        'It had always been exactly like that.',
      );
    });

    test('cuts after a closing quote, not the dot', () {
      const text = 'He paused for a long moment. "That is the whole point '
          'of it." Then she started walking';
      expect(
        UtilsAppTextTrim.trim(text),
        'He paused for a long moment. "That is the whole point of it."',
      );
    });

    test('falls back to dropping a trailing paragraph', () {
      const text = 'That makes sense to me, and I think we are aligned on '
          'the big picture here for sure.\n'
          'But the second part is where I start to';
      expect(
        UtilsAppTextTrim.trim(text),
        'That makes sense to me, and I think we are aligned on '
        'the big picture here for sure.',
      );
    });

    test('leaves an empty string untouched', () {
      expect(UtilsAppTextTrim.trim(''), '');
    });

    test('leaves a reply ending on an emoji after punctuation', () {
      const text = 'That sounds great! 😊';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('leaves a reply ending on an emoji with no punctuation', () {
      const text = 'See you tomorrow 👋';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('leaves a reply ending on a ZWJ emoji sequence', () {
      const text = 'Family: 👨‍👩‍👧';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('leaves a reply ending on a skin-toned emoji', () {
      const text = 'Thumbs 👍🏽';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('cuts after a mid-text emoji boundary, not before it', () {
      const text = 'That was a really lovely afternoon and I enjoyed every '
          'minute of it. 😊 and then it got cut mid-sente';
      expect(
        UtilsAppTextTrim.trim(text),
        'That was a really lovely afternoon and I enjoyed every '
        'minute of it. 😊',
      );
    });

    test('keeps an emoji-ended sentence that sits before the cut', () {
      // The last clean close is the 👋, not the earlier period — cutting at
      // the period would silently drop a complete sentence.
      const text = 'That was a really lovely afternoon and it was so nice. '
          'See you tomorrow 👋 and then it got cut off mid-sente';
      expect(
        UtilsAppTextTrim.trim(text),
        'That was a really lovely afternoon and it was so nice. '
        'See you tomorrow 👋',
      );
    });

    test('the paragraph fallback stops at an emoji-ended paragraph', () {
      const text = 'Hey there, it is so good to hear from you again today '
          '👋\nand then it got cut off mid-sente';
      expect(
        UtilsAppTextTrim.trim(text),
        'Hey there, it is so good to hear from you again today 👋',
      );
    });

    test('drops a lone trailing opening action asterisk', () {
      // Cut right after the model opened an action — the trailing `*` is an
      // opener, not a clean close, even though it sits after a period.
      const text = 'That was really thoughtful and genuinely kind of you. *';
      expect(
        UtilsAppTextTrim.trim(text),
        'That was really thoughtful and genuinely kind of you.',
      );
    });

    test('closes an unterminated action at its last inner sentence end', () {
      const text = 'She looks up at him and smiles. *She reaches for the cup. '
          'Then she starts to wal';
      expect(
        UtilsAppTextTrim.trim(text),
        'She looks up at him and smiles. *She reaches for the cup.*',
      );
    });

    test('leaves balanced action asterisks untouched', () {
      const text = 'She looks up at him. *She smiles warmly and waves hello.*';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('leaves a reply ending on a closing action asterisk', () {
      const text = 'That is a wonderful idea and I would love to. *she grins*';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('an emoji glued to the next word is not a boundary', () {
      // `😊and` is mid-sentence decoration; the real boundary is the period.
      const text = 'We had a truly wonderful time together this afternoon. '
          'It was so good 😊and then it got cut off mid-sente';
      expect(
        UtilsAppTextTrim.trim(text),
        'We had a truly wonderful time together this afternoon.',
      );
    });

    test('closes an unterminated parenthetical aside at its inner boundary', () {
      const text = 'She looks over at him and grins. (He had no idea what was '
          'about to happen. Then she reached for the';
      expect(
        UtilsAppTextTrim.trim(text),
        'She looks over at him and grins. (He had no idea what was '
            'about to happen.)',
      );
    });

    test('drops a lone trailing opening parenthesis after a sentence', () {
      const text = 'That is genuinely one of the kindest things anyone has '
          'ever said to me, and I mean that. (';
      expect(
        UtilsAppTextTrim.trim(text),
        'That is genuinely one of the kindest things anyone has '
            'ever said to me, and I mean that.',
      );
    });

    test('leaves balanced parentheses untouched', () {
      const text = 'I think we should go now (before it gets too late).';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('a sad-face emoticon does not read as an unclosed aside', () {
      // The `(` in `:(` is glued to the eyes, not preceded by whitespace, so
      // it must not draw a stray closing paren onto a complete reply.
      const text = 'I really wish you could have been there with me today :(';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('a mid-reply sad-face emoticon is left alone', () {
      const text = 'I was feeling really down about it earlier :( but talking '
          'to you has honestly made the whole day better.';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('drops a bare trailing bullet marker', () {
      const text = 'Here is what I think we should try first, in order.\n'
          '- Start by taking a slow deep breath and settling in.\n- ';
      expect(
        UtilsAppTextTrim.trim(text),
        'Here is what I think we should try first, in order.\n'
            '- Start by taking a slow deep breath and settling in.',
      );
    });

    test('drops a bare trailing numbered marker', () {
      const text = 'Here is what I think we should try first, in order.\n'
          '1. Start by taking a slow deep breath and settling in.\n2. ';
      expect(
        UtilsAppTextTrim.trim(text),
        'Here is what I think we should try first, in order.\n'
            '1. Start by taking a slow deep breath and settling in.',
      );
    });

    test('closes an unterminated code fence', () {
      const text = 'Sure, here is a small example of how you would do that:\n'
          '```dart\nvoid main() {\n  print("hello");';
      expect(
        UtilsAppTextTrim.trim(text),
        'Sure, here is a small example of how you would do that:\n'
            '```dart\nvoid main() {\n  print("hello");\n```',
      );
    });

    test('leaves a balanced code fence untouched', () {
      const text = 'Here is the snippet you asked for:\n'
          '```dart\nvoid main() {}\n```';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('drops a lone trailing opening quote', () {
      // Cut right after the model opened a quote — the trailing `"` is an
      // opener, not a clean close.
      const text =
          'She sets the cup down slowly and looks away for a moment. "';
      expect(
        UtilsAppTextTrim.trim(text),
        'She sets the cup down slowly and looks away for a moment.',
      );
    });

    test('closes an unterminated quote that ends on an ellipsis', () {
      const text = 'She smiles at the thought of it. "I was thinking that '
          'maybe we could...';
      expect(
        UtilsAppTextTrim.trim(text),
        'She smiles at the thought of it. "I was thinking that '
        'maybe we could..."',
      );
    });

    test('closes an unterminated quote at its last inner sentence end', () {
      const text = '"We could go to the beach together. Or maybe we should '
          'stay home and wat';
      expect(
        UtilsAppTextTrim.trim(text),
        '"We could go to the beach together."',
      );
    });

    test('cuts before a quote that opened and never produced a boundary', () {
      const text = 'She smiles at the thought and nods along. "I was thi';
      expect(
        UtilsAppTextTrim.trim(text),
        'She smiles at the thought and nods along.',
      );
    });

    test('does not extend the cut over a dangling opening quote', () {
      // No space before the opener: the `"` after the dot is the start of
      // the unfinished quote, not a closer to keep.
      const text = 'She nods at him and smiles warmly."Hello there, wha';
      expect(
        UtilsAppTextTrim.trim(text),
        'She nods at him and smiles warmly.',
      );
    });

    test('drops a lone trailing curly opening quote', () {
      const text =
          'She sets the cup down slowly and looks away for a moment. “';
      expect(
        UtilsAppTextTrim.trim(text),
        'She sets the cup down slowly and looks away for a moment.',
      );
    });

    test('closes an unterminated curly quote with its curly counterpart', () {
      const text = '“We could go to the beach together. Or maybe we should '
          'stay home and wat';
      expect(
        UtilsAppTextTrim.trim(text),
        '“We could go to the beach together.”',
      );
    });

    test('leaves balanced quotes untouched', () {
      const text = 'He looks up at her. "That is exactly what I meant."';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('apostrophes do not count as dangling quotes', () {
      const text = 'Don\'t worry about it. It\'s going to be fine.';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('keeps a whole-reply unclosed quote with no inner boundary', () {
      // Nothing to cut to — never return empty.
      const text = '"I was just thinking that we could maybe go';
      expect(UtilsAppTextTrim.trim(text), text);
    });
  });

  // A straight `"` opens and closes with the SAME character, so counting
  // occurrences cannot tell an unclosed quote from a balanced one. An even
  // number of `"` — two unclosed openers, or one stray literal quote plus a
  // real opener — used to read as "balanced" and let the dangling quote
  // through untouched.
  group('UtilsAppTextTrim.trim — unbalanced straight quotes', () {
    test('closes a lone opening quote that ends on an ellipsis', () {
      expect(UtilsAppTextTrim.trim('"Mmmh...'), '"Mmmh..."');
    });

    test('closes an opener even with an EVEN quote count (two openers)', () {
      const text = 'He said "hi there. "Mmmh...';
      expect(UtilsAppTextTrim.trim(text), 'He said "hi there."');
    });

    test('cuts back past a THIRD unclosed opener to the first', () {
      const text = '"That was honestly one of the nicest afternoons I have had '
          'in a long while. "And then. "And...';
      expect(
        UtilsAppTextTrim.trim(text),
        '"That was honestly one of the nicest afternoons I have had '
        'in a long while."',
      );
    });

    test('keeps the original when closing the quote would nuke too much', () {
      const text = '"One thing. "Two things. "Three thi...';
      expect(UtilsAppTextTrim.trim(text), text);
    });

    test('closes a fresh opener that follows a balanced pair', () {
      const text = 'She said "yes." "Mmmh...';
      expect(UtilsAppTextTrim.trim(text), 'She said "yes." "Mmmh..."');
    });

    test('a stray literal quote does not hide a later unclosed opener', () {
      const text = 'The 6" pipe rattled. "Mmmh...';
      final out = UtilsAppTextTrim.trim(text);
      expect(out, isNot(endsWith('...')));
      expect(out, isNot(equals(text)));
    });

    test('closes an opener glued to the preceding period', () {
      const text = 'She nods warmly."Mmmh...';
      expect(UtilsAppTextTrim.trim(text), 'She nods warmly."Mmmh..."');
    });

    test('closes a dialogue opener that follows an action asterisk', () {
      const text = '*She tilts her head.* "Mmmh...';
      expect(UtilsAppTextTrim.trim(text), '*She tilts her head.* "Mmmh..."');
    });
  });

  // Action asterisks are the other symmetric delimiter and share the exact
  // same even-count blind spot.
  group('UtilsAppTextTrim.trim — unbalanced action asterisks', () {
    test('closes an opener even with an EVEN asterisk count', () {
      const text = '*She smiles warmly. *She reaches for the cup...';
      expect(UtilsAppTextTrim.trim(text), '*She smiles warmly.*');
    });
  });

  // A cut can leave more than one delimiter of DIFFERENT kinds open; they must
  // be closed innermost-first so the repair is well-formed.
  group('UtilsAppTextTrim.trim — nested delimiters close in order', () {
    test('closes an unclosed quote inside an unclosed parenthetical', () {
      const text = 'She grins. ("come here now. Then she reached for the';
      expect(UtilsAppTextTrim.trim(text), 'She grins. ("come here now.")');
    });

    test('closes an unclosed quote inside an unclosed action', () {
      const text = 'She says *softly, "come here now. Then she paused and';
      expect(
        UtilsAppTextTrim.trim(text),
        'She says *softly, "come here now."*',
      );
    });
  });

  // A repair must never itself be a broken/trailing sentence. Feeding the
  // cleaner's own output back through it must be a fixpoint — if the first pass
  // left a dangling delimiter or an unfinished tail, the second pass would
  // change it.
  group('UtilsAppTextTrim.trim — the repair is always well-formed', () {
    void expectWellFormed(String input) {
      final once = UtilsAppTextTrim.trim(input);
      expect(once, isNotEmpty, reason: 'empty result for: $input');
      final twice = UtilsAppTextTrim.trim(once);
      expect(
        twice,
        once,
        reason: 'not a fixpoint — first pass left work undone for: $input',
      );
    }

    const samples = [
      '"Mmmh...',
      'He said "hi there. "Mmmh...',
      '"One thing. "Two things. "Three thi...',
      'The 6" pipe rattled. "Mmmh...',
      'She nods warmly."Mmmh...',
      '*She tilts her head.* "Mmmh...',
      '*She smiles warmly. *She reaches for the cup...',
      'She grins. ("come here now. Then she reached for the',
      'She says *softly, "come here now. Then she paused and',
      'She said." Then she walked away without another word.',
      '"I was just thinking that we could maybe go',
      'A plain sentence that simply got cut off mid-wo',
    ];

    for (final sample in samples) {
      test('fixpoint: ${sample.length > 32 ? '${sample.substring(0, 32)}…' : sample}',
          () => expectWellFormed(sample));
    }

    test('every prefix of a mixed roleplay reply repairs to a fixpoint', () {
      const reply = '*She leans in close.* "I was wondering," she said very '
          'softly. "Could we... maybe go out?" (He only smiled.) 😊';
      for (var i = 1; i <= reply.length; i++) {
        expectWellFormed(reply.substring(0, i));
      }
    });
  });
}
