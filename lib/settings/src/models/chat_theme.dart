import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_theme.g.dart';

enum ChatLayoutTypeEnum { bubbles, flat }

@immutable
@JsonSerializable(explicitToJson: true)
class ChatTheme {
  // → shadow_width  (usually px for box-shadow)

  const ChatTheme({
    required this.name,
    required this.layoutType,
    required this.backgroundColor,
    required this.userBackgroundColor,
    required this.assistantBackgroundColor,
    required this.userTextColor,
    required this.assistantTextColor,
    required this.italicColor,
    required this.underlineColor,
    required this.quoteColor,
    required this.dividerColor,
    required this.asteriskColor,
    required this.userMetaColor,
    required this.assistantMetaColor,
    required this.blurTintColor,
    required this.shadowColor,
    required this.textShadowColor,
    required this.borderColor,
    required this.blurStrength,
    required this.shadowWidth,
  });

  factory ChatTheme.fromJson(Map<String, dynamic> json) =>
      _$ChatThemeFromJson(json);
  final String name;
  final ChatLayoutTypeEnum layoutType;

  // Chat container
  final int backgroundColor; // → --chat-tint-color (main chat area background)

  // Message backgrounds (blur tints)
  final int userBackgroundColor; // → --user-mes-blur-tint-color (.mes.user)
  final int
  assistantBackgroundColor; // → --bot-mes-blur-tint-color (.mes.char / .mes.default)

  // Message text
  final int userTextColor; // normal text in user messages
  final int assistantTextColor; // normal text in assistant messages
  final int italicColor; // → --italics-text-color (em, i, *text*)
  final int underlineColor; // → --underline-text-color (u, a, links)
  final int quoteColor; // → --quote-text-color (blockquote, quotes)

  // Meta / extra
  final int dividerColor; // dividers, separators
  final int asteriskColor; // *action* text (kept from your original)
  final int userMetaColor; // username / timestamp for user
  final int assistantMetaColor; // username / timestamp for assistant

  // Message styling (bubbles)
  final int blurTintColor; // → --blur-tint-color (general message blur overlay)
  final int shadowColor; // → --shadow-color (box-shadow on .mes)
  final int textShadowColor;
  final int borderColor; // → --border-color (border on .mes)

  final double blurStrength; // → blur_strength (usually px)
  final double shadowWidth;

  static const ChatTheme azure = ChatTheme(
    name: 'Azure',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0x00171717,
    userBackgroundColor: 0x33001CAE,
    assistantBackgroundColor: 0x38000D39,
    userTextColor: 0xFFABC6DF,
    assistantTextColor: 0xFFABC6DF,
    italicColor: 0xFFFFFFFF,
    underlineColor: 0xFFBCE7CF,
    quoteColor: 0xFF6F85FD,
    asteriskColor: 0xFFFFFFFF,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3ABC6DF,
    assistantMetaColor: 0xB3ABC6DF,
    blurTintColor: 0x9B171E21,
    // havoks opage BG:
    // shadowColor: 0xFF000000,
    shadowColor: 0x00000000,
    textShadowColor: 0xFF000000,
    borderColor: 0x7F000000,
    blurStrength: 11,
    shadowWidth: 5,
  );

  static const ChatTheme cappuccino = ChatTheme(
    name: 'Cappuccino',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0xBF322D32,
    userBackgroundColor: 0xBF221E20,
    assistantBackgroundColor: 0xBF221E20,
    userTextColor: 0xFFEBEBEB,
    assistantTextColor: 0xFFEBEBEB,
    italicColor: 0xFFE6D2BE,
    underlineColor: 0xFFCDB4A0,
    quoteColor: 0xFFA58C73,
    asteriskColor: 0xFFE6D2BE,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3EBEBEB,
    assistantMetaColor: 0xB3EBEBEB,
    // blurTintColor: 0xF2221E20, // opague!
    // background-color: rgba(34, 30, 32, 0.75);
    // toggle-dependent.css:306
    // Best Match body.bubblechat .mes
    // var(--SmartThemeBotMesBlurTintColor)
    blurTintColor: 0xBF221E20,
    shadowColor: 0x4C000000,
    textShadowColor: 0x4C000000,
    borderColor: 0xE2505050,
    blurStrength: 3,
    shadowWidth: 1,
  );

  static const ChatTheme celestialMacaron = ChatTheme(
    name: 'Celestial Macaron',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0xE5121A28,
    userBackgroundColor: 0xB233435A,
    assistantBackgroundColor: 0xBF172437,
    userTextColor: 0xFFE5AFA2,
    assistantTextColor: 0xFFE5AFA2,
    italicColor: 0xFF9293A1,
    underlineColor: 0xFF9DD7C6,
    quoteColor: 0xFFC5CACE,
    asteriskColor: 0xFF9293A1,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3E5AFA2,
    assistantMetaColor: 0xB3E5AFA2,
    blurTintColor: 0xE5172437,
    shadowColor: 0x4C000000,
    textShadowColor: 0x4C000000,
    borderColor: 0xED3C4A6E,
    blurStrength: 10,
    shadowWidth: 1,
  );

  static const ChatTheme darkLite = ChatTheme(
    name: 'Dark Lite',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0xFF171717,
    userBackgroundColor: 0xE61E1E1E,
    assistantBackgroundColor: 0xE61E1E1E,
    userTextColor: 0xFFDCDCD2,
    assistantTextColor: 0xFFDCDCD2,
    italicColor: 0xFF919191,
    underlineColor: 0xFFBCE7CF,
    quoteColor: 0xFFE18A24,
    asteriskColor: 0xFF919191,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3DCDCD2,
    assistantMetaColor: 0xB3DCDCD2,
    blurTintColor: 0xFF171717,
    shadowColor: 0xFF000000,
    textShadowColor: 0xFF000000,
    borderColor: 0xFF000000,
    blurStrength: 10,
    shadowWidth: 2,
  );

  static const ChatTheme darkV1 = ChatTheme(
    name: 'Dark V 1.0',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0xE51D2128,
    userBackgroundColor: 0xE51D2128,
    assistantBackgroundColor: 0xE51D2128,
    userTextColor: 0xFFCFCFC5,
    assistantTextColor: 0xFFCFCFC5,
    italicColor: 0xFF919191,
    underlineColor: 0xFF919191,
    quoteColor: 0xFFC6C197,
    asteriskColor: 0xFF919191,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3CFCFC5,
    assistantMetaColor: 0xB3CFCFC5,
    blurTintColor: 0xE51D2128,
    shadowColor: 0xE5000000,
    textShadowColor: 0xE5000000,
    borderColor: 0xFF000000,
    blurStrength: 13,
    shadowWidth: 2,
  );

  static const ChatTheme glimmer = ChatTheme(
    name: 'Glimmer',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0x00121212,
    userBackgroundColor: 0x4D1E1E1E,
    assistantBackgroundColor: 0x0DFFFFFF,
    userTextColor: 0xFFC6C6C6,
    assistantTextColor: 0xFFC6C6C6,
    italicColor: 0xFF6C6C6C,
    underlineColor: 0xFFDFDFDF,
    quoteColor: 0xFF51A0DE,
    asteriskColor: 0xFF6C6C6C,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3C6C6C6,
    assistantMetaColor: 0xB3C6C6C6,
    // picked directly in browser
    // blurTintColor: 0xFF1E1E1E,
    blurTintColor: 0x00FFFFFF,
    // causes BG to become opaque
    // shadowColor: 0xFF1E1E1E,
    shadowColor: 0x001E1E1E,
    textShadowColor: 0xFF1E1E1E,
    borderColor: 0x1AC6C6C6,
    blurStrength: 8,
    shadowWidth: 3,
  );

  static const ChatTheme moonlitEchoes = ChatTheme(
    name: 'Moonlit Echoes',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0x00FFFFFF,
    userBackgroundColor: 0x802D2D2D,
    assistantBackgroundColor: 0xA6272727,
    userTextColor: 0xFFCCCCCC,
    assistantTextColor: 0xFFCCCCCC,
    italicColor: 0xFF969696,
    underlineColor: 0xFFFAC679,
    quoteColor: 0xFF51A0DE,
    asteriskColor: 0xFF969696,
    dividerColor: 0xFFBDBDBD,
    userMetaColor: 0xB3CCCCCC,
    assistantMetaColor: 0xB3CCCCCC,
    // picked directly in browser
    // blurTintColor: 0xA6212121,
    blurTintColor: 0x0DFFFFFF,
    shadowColor: 0x80000000,
    textShadowColor: 0x80000000,
    borderColor: 0x00FFFFFF,
    blurStrength: 8,
    shadowWidth: 3,
  );

  // Neon wave bubbles: hot-pink edge + cyan glow on dark glass; inline roles
  // glow (cyan actions, pink speech). Pairs with the neon ThemeData.
  static const ChatTheme cardwaveNeon = ChatTheme(
    name: 'Cardwave Neon',
    layoutType: ChatLayoutTypeEnum.bubbles,
    backgroundColor: 0x73070316,
    userBackgroundColor: 0xCC2A0E3A,
    assistantBackgroundColor: 0xCC140A2E,
    userTextColor: 0xFFF2F0FF,
    assistantTextColor: 0xFFF2F0FF,
    italicColor: 0xFF7FE3FF,
    underlineColor: 0xFF00F8FF,
    quoteColor: 0xFFFF8FD0,
    asteriskColor: 0xFF7FE3FF,
    dividerColor: 0x55FFFFFF,
    userMetaColor: 0xB3F2F0FF,
    assistantMetaColor: 0xB3F2F0FF,
    blurTintColor: 0x99120A2E,
    // MessageLayoutBubble draws the glow using shadowWidth as the blur radius.
    shadowColor: 0x6600F8FF,
    textShadowColor: 0xCC000000,
    borderColor: 0xCCFF2DA8,
    blurStrength: 12,
    shadowWidth: 8,
  );

  // Same neon palette, flat layout: full-width turns, no bubble/border/glow.
  // The neon reads from the inline accents + a pink hairline between turns.
  static const ChatTheme cardwaveNeonFlat = ChatTheme(
    name: 'Cardwave Neon (Flat)',
    layoutType: ChatLayoutTypeEnum.flat,
    backgroundColor: 0x59070316,
    userBackgroundColor: 0x4D2A0E3A,
    assistantBackgroundColor: 0x40140A2E,
    userTextColor: 0xFFF2F0FF,
    assistantTextColor: 0xFFF2F0FF,
    italicColor: 0xFF7FE3FF,
    underlineColor: 0xFF00F8FF,
    quoteColor: 0xFFFF8FD0,
    asteriskColor: 0xFF7FE3FF,
    dividerColor: 0x4DFF2DA8,
    userMetaColor: 0xB3F2F0FF,
    assistantMetaColor: 0xB3F2F0FF,
    blurTintColor: 0x99100A26,
    shadowColor: 0x00000000,
    textShadowColor: 0xCC000000,
    borderColor: 0x00000000,
    blurStrength: 12,
    shadowWidth: 0,
  );

  static List<ChatTheme> get presets => [
    azure,
    cappuccino,
    celestialMacaron,
    darkLite,
    darkV1,
    glimmer,
    moonlitEchoes,
    cardwaveNeon,
    cardwaveNeonFlat,
    nativeLight(),
    nativeDark(),
  ];

  static ChatTheme nativeLight() {
    final theme = ThemeData.light(useMaterial3: true);
    final colorScheme = theme.colorScheme;

    return ChatTheme(
      name: 'Native Light',
      layoutType: ChatLayoutTypeEnum.flat,
      backgroundColor: colorScheme.surface.toARGB32(),
      userBackgroundColor: colorScheme.primaryContainer.toARGB32(),
      assistantBackgroundColor: colorScheme.surfaceContainerHighest.toARGB32(),
      userTextColor: colorScheme.onPrimaryContainer.toARGB32(),
      assistantTextColor: colorScheme.onSurfaceVariant.toARGB32(),
      italicColor: colorScheme.onSurface.toARGB32(),
      underlineColor: colorScheme.primary.toARGB32(),
      quoteColor: colorScheme.outline.toARGB32(),
      dividerColor: theme.dividerColor.toARGB32(),
      asteriskColor: colorScheme.secondary.toARGB32(),
      userMetaColor: colorScheme.onPrimaryContainer
          .withValues(alpha: 0.7)
          .toARGB32(),
      assistantMetaColor: colorScheme.onSurfaceVariant
          .withValues(alpha: 0.7)
          .toARGB32(),
      blurTintColor: 0x00000000,
      shadowColor: 0x00000000,
      textShadowColor: 0x00000000,
      borderColor: 0x00000000,
      blurStrength: 0,
      shadowWidth: 0,
    );
  }

  static ChatTheme nativeDark() {
    final theme = ThemeData.dark(useMaterial3: true);
    final colorScheme = theme.colorScheme;

    return ChatTheme(
      name: 'Native Dark',
      layoutType: ChatLayoutTypeEnum.flat,
      backgroundColor: colorScheme.surface.toARGB32(),
      userBackgroundColor: colorScheme.primaryContainer.toARGB32(),
      assistantBackgroundColor: colorScheme.surfaceContainerHighest.toARGB32(),
      userTextColor: colorScheme.onPrimaryContainer.toARGB32(),
      assistantTextColor: colorScheme.onSurfaceVariant.toARGB32(),
      italicColor: colorScheme.onSurface.toARGB32(),
      underlineColor: colorScheme.primary.toARGB32(),
      quoteColor: colorScheme.outline.toARGB32(),
      dividerColor: theme.dividerColor.toARGB32(),
      asteriskColor: colorScheme.secondary.toARGB32(),
      userMetaColor: colorScheme.onPrimaryContainer
          .withValues(alpha: 0.7)
          .toARGB32(),
      assistantMetaColor: colorScheme.onSurfaceVariant
          .withValues(alpha: 0.7)
          .toARGB32(),
      blurTintColor: 0x00000000,
      shadowColor: 0x00000000,
      textShadowColor: 0x00000000,
      borderColor: 0x00000000,
      blurStrength: 0,
      shadowWidth: 0,
    );
  }

  Map<String, dynamic> toJson() => _$ChatThemeToJson(this);

  // --- Resolution Helpers ---

  Color resolveUserTextColor() => Color(userTextColor);

  Color resolveAssistantTextColor() => Color(assistantTextColor);

  Color resolveUserBackgroundColor() => Color(userBackgroundColor);

  Color resolveAssistantBackgroundColor() => Color(assistantBackgroundColor);

  Color resolveUserMetaColor() => Color(userMetaColor);

  Color resolveAssistantMetaColor() => Color(assistantMetaColor);

  Color resolveDividerColor() => Color(dividerColor);

  Color resolveItalicColor() => Color(italicColor);

  Color resolveUnderlineColor() => Color(underlineColor);

  Color resolveQuoteColor() => Color(quoteColor);

  Color resolveAsteriskColor() => Color(asteriskColor);

  Color resolveShadowColor() => Color(shadowColor);

  Color resolveTextShadowColor() => Color(textShadowColor);

  Color resolveBlurTintColor() => Color(blurTintColor);

  Color resolveBorderColor() => Color(borderColor);

  Color resolveBackgroundColor() => Color(backgroundColor);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatTheme &&
          name == other.name &&
          layoutType == other.layoutType &&
          backgroundColor == other.backgroundColor &&
          userBackgroundColor == other.userBackgroundColor &&
          assistantBackgroundColor == other.assistantBackgroundColor &&
          userTextColor == other.userTextColor &&
          assistantTextColor == other.assistantTextColor &&
          italicColor == other.italicColor &&
          underlineColor == other.underlineColor &&
          quoteColor == other.quoteColor &&
          dividerColor == other.dividerColor &&
          asteriskColor == other.asteriskColor &&
          userMetaColor == other.userMetaColor &&
          assistantMetaColor == other.assistantMetaColor &&
          blurTintColor == other.blurTintColor &&
          shadowColor == other.shadowColor &&
          textShadowColor == other.textShadowColor &&
          borderColor == other.borderColor &&
          blurStrength == other.blurStrength &&
          shadowWidth == other.shadowWidth;

  @override
  int get hashCode =>
      name.hashCode ^
      layoutType.hashCode ^
      backgroundColor.hashCode ^
      userBackgroundColor.hashCode ^
      assistantBackgroundColor.hashCode ^
      userTextColor.hashCode ^
      assistantTextColor.hashCode ^
      italicColor.hashCode ^
      underlineColor.hashCode ^
      quoteColor.hashCode ^
      dividerColor.hashCode ^
      asteriskColor.hashCode ^
      userMetaColor.hashCode ^
      assistantMetaColor.hashCode ^
      blurTintColor.hashCode ^
      shadowColor.hashCode ^
      textShadowColor.hashCode ^
      borderColor.hashCode ^
      blurStrength.hashCode ^
      shadowWidth.hashCode;
}
