import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts the estimate lands in a plausible band rather than pinning exact
/// values, so weight tweaks don't break tests as long as the count stays in
/// the right category.
Future<void> expectTokensInBand(String text, int min, int max) async {
  final count = await UtilsLlm.countTokens(text);
  expect(
    count,
    inInclusiveRange(min, max),
    reason: '"$text" (${text.length} chars) estimated at $count tokens, '
        'expected $min..$max',
  );
}

void main() {
  group('countTokens basics', () {
    test('empty string is zero tokens', () async {
      expect(await UtilsLlm.countTokens(''), 0);
    });

    test('repeat calls return the same count (cache path)', () async {
      const text = 'cache me if you can';
      final first = await UtilsLlm.countTokens(text);
      final second = await UtilsLlm.countTokens(text);
      expect(second, first);
    });
  });

  group('countTokens per script', () {
    test('English stays near chars/4', () async {
      await expectTokensInBand(
        'The quick brown fox jumps over the lazy dog.',
        9,
        14,
      );
    });

    test('Chinese counts roughly one token per character', () async {
      await expectTokensInBand('今天天气很好，我们去公园散步吧。', 12, 20);
    });

    test('Japanese counts roughly one token per character', () async {
      await expectTokensInBand('こんにちは、元気ですか？', 9, 15);
    });

    test('Korean counts roughly one token per syllable', () async {
      await expectTokensInBand('안녕하세요, 만나서 반갑습니다.', 10, 18);
    });

    test('Hindi lands between Latin and CJK density', () async {
      await expectTokensInBand('नमस्ते, आप कैसे हैं?', 9, 16);
    });

    test('Russian counts roughly one token per two characters', () async {
      await expectTokensInBand('Привет, как дела?', 6, 10);
    });

    test('Vietnamese diacritics push the count above the old chars/4',
        () async {
      const text = 'Xin chào, tôi là một trợ lý ảo.';
      final count = await UtilsLlm.countTokens(text);
      final oldEstimate = (text.length / 4).ceil();
      expect(count, greaterThan(oldEstimate));
      expect(count, lessThanOrEqualTo(text.length));
    });

    test('emoji count as roughly one token each, not surrogate halves',
        () async {
      expect(await UtilsLlm.countTokens('👍🎉'), 2);
    });

    test('CJK text costs several times more than ASCII of equal length',
        () async {
      final ascii = 'a' * 40;
      final cjk = '好' * 40;
      final asciiCount = await UtilsLlm.countTokens(ascii);
      final cjkCount = await UtilsLlm.countTokens(cjk);
      expect(cjkCount, greaterThanOrEqualTo(asciiCount * 3));
    });

    test('mixed-language text sums per-script weights', () async {
      // "Hello " (6 ASCII = 1.5) + 4 CJK (4.0) => ~6 tokens, not 3 (chars/4).
      await expectTokensInBand('Hello 世界你好', 5, 7);
    });
  });
}
