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

    test('an emoji glued to the next word is not a boundary', () {
      // `😊and` is mid-sentence decoration; the real boundary is the period.
      const text = 'We had a truly wonderful time together this afternoon. '
          'It was so good 😊and then it got cut off mid-sente';
      expect(
        UtilsAppTextTrim.trim(text),
        'We had a truly wonderful time together this afternoon.',
      );
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
}
