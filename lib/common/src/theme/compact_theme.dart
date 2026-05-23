import 'package:cardwave/common/src/theme/no_transitions_builder.dart';
import 'package:flutter/material.dart';

/// Material 3 disabled-state alpha applied to foreground tokens like
/// `onSurface` for greyed-out icons, labels, and trailing widgets.
const double kDisabledAlpha = 0.38;

const String _fontFamily = 'NotoSans';

const TextTheme _compactTextTheme = TextTheme(
  bodyLarge: TextStyle(fontSize: 14),
  titleMedium: TextStyle(fontSize: 14),
  titleLarge: TextStyle(fontSize: 16),
);

InputDecorationTheme _buildInputDecorationTheme(ColorScheme scheme) {
  final radius = const BorderRadius.all(Radius.circular(8));
  return InputDecorationTheme(
    filled: true,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.error, width: 2),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always,
    hintStyle: const TextStyle(color: Colors.grey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  );
}

ThemeData _buildBaseTheme({required Brightness brightness}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blueGrey,
    brightness: brightness,
  );
  final inputDecorationTheme = _buildInputDecorationTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    // brightness: brightness,
    fontFamily: _fontFamily,
    // fontFamilyFallback: const [_fontFamily],
    colorScheme: colorScheme,
    textTheme: _compactTextTheme,
    popupMenuTheme: const PopupMenuThemeData(menuPadding: EdgeInsets.zero),
    chipTheme: const ChipThemeData(labelPadding: EdgeInsets.zero),
    // appBarTheme: const AppBarTheme(toolbarHeight: kToolbarHeight),
    // appBarTheme: const AppBarTheme(toolbarHeight: kCompactAppBarHeight),
    listTileTheme: const ListTileThemeData(),
    inputDecorationTheme: inputDecorationTheme,
    // cardTheme: CardThemeData(clipBehavior: Clip.antiAlias),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: NoTransitionsBuilder(),
        TargetPlatform.iOS: NoTransitionsBuilder(),
        TargetPlatform.windows: NoTransitionsBuilder(),
        TargetPlatform.macOS: NoTransitionsBuilder(),
        TargetPlatform.linux: NoTransitionsBuilder(),
      },
    ),
  );
}

final ThemeData compactLightTheme = _buildBaseTheme(
  brightness: Brightness.light,
);

final ThemeData compactDarkTheme = _buildBaseTheme(
  brightness: Brightness.dark,
);

