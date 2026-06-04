import 'package:cardwave/common/src/theme/no_transitions_builder.dart';
import 'package:flutter/material.dart';

/// Material 3 disabled-state alpha applied to foreground tokens like
/// `onSurface` for greyed-out icons, labels, and trailing widgets.
const double kDisabledAlpha = 0.38;

/// Brand wordmark gradient — hot pink to violet. Both ends contrast with
/// the teal top of the backdrop, so it reads in light and dark; the older
/// cyan-led fill disappeared against the teal. Default fill for
/// `GradientText`.
const LinearGradient kCardwaveWordmarkGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFFF0099), Color(0xFF8A2BE2)],
);

/// App backdrop for dark mode — a deep synthwave gradient (indigo to violet
/// to deep wine). Richly saturated but kept dark (low brightness), so the
/// bright pink and cyan accents glow against it instead of looking muddy, and
/// bright pink never vibrates the way it did on a bright-blue backdrop. Pink
/// labels still read because the bright accent sits on a much darker ground.
const LinearGradient kCardwaveBackdropDark = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF170A42), Color(0xFF3A0E5E), Color(0xFF50123A)],
);

/// App backdrop for light mode — the same cool hues pulled to pastel, so the
/// dark on-surface text the light scheme uses stays readable across the whole
/// gradient. Like the dark backdrop it avoids pink so the pink accent text
/// keeps its contrast.
const LinearGradient kCardwaveBackdropLight = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFBFEAF4), Color(0xFFCFD4F4), Color(0xFFDDCBEF)],
);

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

/// Shared theme builder for both families. [neon] switches on the synthwave
/// chrome — a transparent scaffold and app bar so the backdrop gradient
/// (painted behind the Navigator in MyApp) shows through, plus pink app-bar
/// icons that match the pink text buttons. The standard family leaves those
/// at their opaque Material defaults.
ThemeData _buildTheme({required ColorScheme colorScheme, required bool neon}) {
  final inputDecorationTheme = _buildInputDecorationTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    colorScheme: colorScheme,
    textTheme: _compactTextTheme,
    scaffoldBackgroundColor: neon ? Colors.transparent : null,
    appBarTheme: neon
        ? AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: IconThemeData(color: colorScheme.primary),
            actionsIconTheme: IconThemeData(color: colorScheme.primary),
          )
        : null,
    popupMenuTheme: const PopupMenuThemeData(menuPadding: EdgeInsets.zero),
    chipTheme: const ChipThemeData(labelPadding: EdgeInsets.zero),
    listTileTheme: const ListTileThemeData(),
    inputDecorationTheme: inputDecorationTheme,
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

ColorScheme _neonScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ColorScheme.fromSeed(
    seedColor: const Color(0xFFFF0099),
    brightness: brightness,
  ).copyWith(
    primary: isDark ? const Color(0xFFFF0099) : const Color(0xFFFF1E9E),
    onPrimary: Colors.white,
    secondary: isDark ? const Color(0xFF00F8FF) : const Color(0xFF00C2DE),
    onSecondary: Colors.black,
    tertiary: const Color(0xFFBD4EFF),
    onTertiary: Colors.white,
  );
}

/// Standard (original) blue-grey Material themes.
final ThemeData compactLightTheme = _buildTheme(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blueGrey,
    brightness: Brightness.light,
  ),
  neon: false,
);

final ThemeData compactDarkTheme = _buildTheme(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blueGrey,
    brightness: Brightness.dark,
  ),
  neon: false,
);

/// Neon synthwave themes — pair with the backdrop gradients above.
final ThemeData neonLightTheme = _buildTheme(
  colorScheme: _neonScheme(Brightness.light),
  neon: true,
);

final ThemeData neonDarkTheme = _buildTheme(
  colorScheme: _neonScheme(Brightness.dark),
  neon: true,
);

