import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

@immutable
class MarkdownCacheKey {
  const MarkdownCacheKey({
    required this.textColor,
    required this.underlineColor,
    required this.quoteColor,
    required this.asteriskColor,
    required this.surfaceColor,
    required this.shadowColor,
  });
  final Color? textColor;
  final Color? underlineColor;
  final Color? quoteColor;
  final Color? asteriskColor;
  final Color? surfaceColor;
  final Color? shadowColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownCacheKey &&
          textColor == other.textColor &&
          underlineColor == other.underlineColor &&
          quoteColor == other.quoteColor &&
          asteriskColor == other.asteriskColor &&
          surfaceColor == other.surfaceColor &&
          shadowColor == other.shadowColor;

  @override
  int get hashCode => Object.hash(
    textColor,
    underlineColor,
    quoteColor,
    asteriskColor,
    surfaceColor,
    shadowColor,
  );
}

class MarkdownCacheValue {
  const MarkdownCacheValue(this.config, this.generator);
  final MarkdownConfig config;
  final MarkdownGenerator generator;
}

/// Bounded cache: every unique color tuple (theme switch, custom user color,
/// per-message tint) inserts a new entry that would otherwise live for the
/// app's lifetime. At [_markdownCacheCap] entries the cache is cleared
/// wholesale — same eviction shape as `_regexCache` in `lorebook_service.dart`.
/// The map is private so the cap is enforced — only [putMarkdownCache] writes.
const int _markdownCacheCap = 500;
final _markdownCache = <MarkdownCacheKey, MarkdownCacheValue>{};

MarkdownCacheValue? lookupMarkdownCache(MarkdownCacheKey key) =>
    _markdownCache[key];

void putMarkdownCache(MarkdownCacheKey key, MarkdownCacheValue value) {
  if (_markdownCache.length >= _markdownCacheCap) {
    _markdownCache.clear();
  }
  _markdownCache[key] = value;
}
