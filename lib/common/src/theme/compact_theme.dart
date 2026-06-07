import 'package:cardwave/common/src/theme/no_transitions_builder.dart';
import 'package:flutter/material.dart';

// ============================================================================
//  CARDWAVE THEME — Default (blueGrey M3) + Neon Wave
//
//  Two families, four ThemeData objects:
//    compactLightTheme / compactDarkTheme   → original blueGrey M3 (unchanged)
//    neonLightTheme    / neonDarkTheme      → the neon wave
//
//  WHY THE NEON FAMILY FIXES EVERY SCREEN (not just the card grid):
//  the whole app is driven by ColorScheme tokens — SectionHeaderBand uses
//  `surfaceContainerHighest`, dense rows use `onSurfaceVariant` on transparent
//  backgrounds, dialogs/menus use `surface`, fields use `outlineVariant`.
//  So the neon family defines a full DARK surface ramp (not just accent
//  overrides). Get the surfaces right and the settings table, dialogs, drawers
//  and the edit form all become readable automatically.
//
//  THE WAVE IS THE SIGNATURE BACKGROUND. Flutter's ThemeData has NO gradient
//  slot (scaffoldBackgroundColor is a single Color), so the cyan→violet→
//  magenta wave must be painted ONCE behind the app. The neon scaffold is
//  therefore TRANSPARENT, and you add one app-level background in MyApp (see
//  the snippet by kCardwaveBackdropDark below). Surfaces stay opaque dark, so
//  cards/dialogs/tables read cleanly while the wave glows in the gutters and
//  behind chromeless rows — the vibrant look, kept readable.
// ============================================================================

/// Material 3 disabled-state alpha applied to foreground tokens like
/// `onSurface` for greyed-out icons, labels, and trailing widgets.
const double kDisabledAlpha = 0.38;

// ---- Neon accents ---------------------------------------------------------
const Color kNeonPink = Color(0xFFFF2DA8); // primary (brightened for dark)
const Color kNeonPinkDeep = Color(0xFFFF0099); // button fills / wordmark end
const Color kNeonCyan = Color(0xFF00F8FF); // secondary / focus / icons
const Color kNeonViolet = Color(0xFFBD4EFF); // tertiary

// ---- Neon dark surface ramp (darkest → lightest) --------------------------
const Color kNeonScaffold = Color(0xFF0C0620); // deepest — scaffold base
const Color kNeonSurface = Color(0xFF1A1336); // cards, dialogs, fields
const Color kNeonContainerHigh = Color(0xFF241B47); // menu group cards
const Color kNeonContainerHighest = Color(0xFF2C2152); // section header bands
const Color kNeonOnSurface = Color(0xFFF2F0FF);
const Color kNeonOnSurfaceVariant = Color(0xFFC2BAE6); // muted trailing text
const Color kNeonOutline = Color(0xFF6B5FA0);
const Color kNeonOutlineVariant = Color(0xFF3A3162); // dividers, field borders

/// Dark translucent AppBar fill. NOT transparent — a see-through bar over the
/// wave's bright cyan crest is what killed icon contrast on the chat/settings
/// screens. A hint of the backdrop still tints through the alpha.
const Color kNeonBar = Color(0xD60C0620);

/// Brand wordmark gradient (dark mode) — cyan → white shine → hot pink. The
/// white core only pops on the dark backdrop; on light it washes out, so light
/// mode uses [kCardwaveWordmarkGradientLight] instead.
const LinearGradient kCardwaveWordmarkGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [kNeonCyan, Color(0xFFFFFFFF), kNeonPinkDeep],
  stops: [0.0, 0.5, 1.0],
);

/// Brand wordmark gradient (light mode) — deep teal → violet → deep pink. No
/// white core (it would disappear on the pastel backdrop); the deeper accents
/// read against light cyan/lavender.
const LinearGradient kCardwaveWordmarkGradientLight = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF008B98), Color(0xFF8A2BE2), Color(0xFFD1006F)],
);

/// THE WAVE — the signature background (cyan-teal crest → neon violet → hot
/// magenta). Paint it ONCE behind every screen via MyApp's `builder`, because
/// ThemeData cannot hold a gradient. The neon scaffold is transparent so this
/// shows through:
///
///   MaterialApp(
///     theme: ..., darkTheme: ...,
///     builder: (context, child) {
///       final neon = /* your ThemeNotifier neon flag */;
///       if (!neon) return child!;
///       return Stack(children: [
///         const DecoratedBox(
///           decoration: BoxDecoration(gradient: kCardwaveBackdropDark),
///           child: SizedBox.expand(),
///         ),
///         // veil: rich but readable — keeps text on chromeless rows legible
///         const ColoredBox(color: kCardwaveBackgroundVeil),
///         child!,
///       ]);
///     },
///   )
///
/// (Wrap your existing OverlayError child the same way.)
const LinearGradient kCardwaveBackdropDark = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF129AC0), Color(0xFF6F1CB7), Color(0xFFD11F69)],
);

/// Dark veil laid over the wave so the vibrant gradient stays catchy but text
/// on chromeless surfaces (dense settings rows) keeps its contrast. Tune the
/// alpha (0x59 ≈ 35%) up for calmer, down for punchier.
const Color kCardwaveBackgroundVeil = Color(0x59070316);

/// Light-mode wave — same hues pulled to pastel so dark on-surface text stays
/// readable where the wave shows through.
const LinearGradient kCardwaveBackdropLight = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFBFEAF4), Color(0xFFD6CBF4), Color(0xFFF4CBDD)],
);

const String _fontFamily = 'NotoSans';

const TextTheme _compactTextTheme = TextTheme(
  bodyLarge: TextStyle(fontSize: 14),
  titleMedium: TextStyle(fontSize: 14),
  titleLarge: TextStyle(fontSize: 16),
);

// ---------------------------------------------------------------------------
//  ColorSchemes
// ---------------------------------------------------------------------------
ColorScheme _neonScheme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return ColorScheme.fromSeed(
      seedColor: kNeonPink,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kNeonPink,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF55093A),
      onPrimaryContainer: const Color(0xFFFFD7EE),
      secondary: kNeonCyan,
      onSecondary: Colors.black,
      // Dark indigo, NOT teal. The media-grid column header uses this token;
      // a teal container read as an off-brand "green band" over the wave.
      secondaryContainer: const Color(0xFF1E2748),
      onSecondaryContainer: const Color(0xFFCDE9FF),
      tertiary: kNeonViolet,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF3A1A5E),
      onTertiaryContainer: const Color(0xFFEBD6FF),
      surface: kNeonSurface,
      onSurface: kNeonOnSurface,
      surfaceContainerLowest: const Color(0xFF0A0418),
      surfaceContainerLow: const Color(0xFF161029),
      surfaceContainer: const Color(0xFF1C1438),
      surfaceContainerHigh: kNeonContainerHigh,
      surfaceContainerHighest: kNeonContainerHighest,
      onSurfaceVariant: kNeonOnSurfaceVariant,
      outline: kNeonOutline,
      outlineVariant: kNeonOutlineVariant,
      error: const Color(0xFFFF6B81),
      onError: Colors.black,
      errorContainer: const Color(0xFF5A1020),
      onErrorContainer: const Color(0xFFFFD9DE),
    );
  }
  // Light neon — pastel wave surfaces, accents pulled a touch deeper so they
  // read on light. Neon is inherently dark; this is the legible light cousin.
  return ColorScheme.fromSeed(
    seedColor: kNeonPink,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFFD1006F),
    onPrimary: Colors.white,
    secondary: const Color(0xFF008B98),
    onSecondary: Colors.white,
    tertiary: const Color(0xFF8A2BE2),
    onTertiary: Colors.white,
    surface: const Color(0xFFFDF4FB),
    onSurface: const Color(0xFF1F1430),
    surfaceContainerHighest: const Color(0xFFF1E4F4),
    onSurfaceVariant: const Color(0xFF5A4A66),
    outlineVariant: const Color(0xFFD9C7E0),
  );
}

// ---------------------------------------------------------------------------
//  Shared component builders
// ---------------------------------------------------------------------------
InputDecorationTheme _buildInputDecorationTheme(
  ColorScheme scheme, {
  required bool neon,
}) {
  final radius = const BorderRadius.all(Radius.circular(8));
  final enabled = neon
      ? scheme.secondary.withValues(alpha: 0.40)
      : scheme.outlineVariant;
  final focus = neon ? scheme.secondary : scheme.primary;
  return InputDecorationTheme(
    filled: true,
    fillColor: neon ? scheme.surfaceContainerHighest : null,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: enabled),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: enabled),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: focus, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: enabled.withValues(alpha: 0.5)),
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
    hintStyle: TextStyle(
      color: neon
          ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
          : Colors.grey,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  );
}

/// Neon card surface, derived from the active [scheme] so it is correct in
/// BOTH light and dark. The app's grid `Card` sets its OWN border per item
/// (error=favorite, primary=recent, else none) and `_MenuGroupCard` sets its
/// own shape too, so this theme intentionally does NOT force a border. It
/// supplies the surface + a soft secondary (cyan/teal) halo via the shadow.
CardThemeData _neonCardTheme(ColorScheme scheme) => CardThemeData(
  color: scheme.surface,
  elevation: 6,
  shadowColor: scheme.secondary.withValues(alpha: 0.85),
  surfaceTintColor: Colors.transparent,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
);

/// The segmented controls (App Theme, Theme Style, Chat/Edit) must read as
/// neon: selected = pink fill, unselected = muted-on-dark.
SegmentedButtonThemeData _neonSegmentedTheme(ColorScheme scheme) =>
    SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.onSurfaceVariant;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.secondary.withValues(alpha: 0.35)),
        ),
      ),
    );

// ---------------------------------------------------------------------------
//  Theme builders
// ---------------------------------------------------------------------------
ThemeData _buildTheme({required ColorScheme colorScheme, required bool neon}) {
  final inputDecorationTheme = _buildInputDecorationTheme(
    colorScheme,
    neon: neon,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    colorScheme: colorScheme,
    textTheme: _compactTextTheme,
    // Transparent so the wave painted in MyApp shows through. Surfaces are
    // opaque (dark in dark mode, light in light mode), so content reads while
    // the wave glows in the gutters.
    scaffoldBackgroundColor: neon ? Colors.transparent : null,
    cardTheme: neon ? _neonCardTheme(colorScheme) : null,
    appBarTheme: neon
        ? AppBarTheme(
            // Dark: translucent dark surface keeps icon contrast over the
            // bright wave crest. Light: surface is near-white and reads as a
            // disconnected white bar, so tint the bar with the backdrop's own
            // top colour at low alpha — the wave flows through it unbroken, so
            // the bar and the content below share one continuous gradient.
            backgroundColor: colorScheme.brightness == Brightness.dark
                ? colorScheme.surface.withValues(alpha: 0.84)
                : kCardwaveBackdropLight.colors.first.withValues(alpha: 0.55),
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: colorScheme.secondary),
            actionsIconTheme: IconThemeData(color: colorScheme.secondary),
            titleTextStyle: TextStyle(
              fontFamily: _fontFamily,
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          )
        : null,
    dividerTheme: neon
        ? DividerThemeData(color: colorScheme.outlineVariant, thickness: 1)
        : null,
    segmentedButtonTheme: neon
        ? _neonSegmentedTheme(colorScheme)
        : const SegmentedButtonThemeData(),
    tabBarTheme: neon
        ? TabBarThemeData(
            labelColor: colorScheme.onSurface,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
          )
        : null,
    switchTheme: neon
        ? SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? colorScheme.onPrimary
                  : null,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (s) =>
                  s.contains(WidgetState.selected) ? colorScheme.primary : null,
            ),
          )
        : null,
    popupMenuTheme: PopupMenuThemeData(
      menuPadding: EdgeInsets.zero,
      color: neon ? colorScheme.surfaceContainerHigh : null,
      surfaceTintColor: neon ? Colors.transparent : null,
    ),
    dialogTheme: neon
        ? DialogThemeData(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
          )
        : null,
    drawerTheme: neon
        ? DrawerThemeData(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
          )
        : null,
    navigationRailTheme: neon
        ? NavigationRailThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: colorScheme.secondary.withValues(alpha: 0.20),
            selectedIconTheme: IconThemeData(color: colorScheme.secondary),
            unselectedIconTheme: IconThemeData(
              color: colorScheme.onSurfaceVariant,
            ),
            selectedLabelTextStyle: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          )
        : null,
    chipTheme: const ChipThemeData(labelPadding: EdgeInsets.zero),
    listTileTheme: neon
        ? ListTileThemeData(iconColor: colorScheme.secondary)
        : const ListTileThemeData(),
    inputDecorationTheme: inputDecorationTheme,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        foregroundColor: neon ? colorScheme.secondary : null,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: neon ? colorScheme.primary : null,
        foregroundColor: neon ? colorScheme.onPrimary : null,
        elevation: neon ? 10 : null,
        shadowColor: neon ? colorScheme.primary.withValues(alpha: 0.9) : null,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: neon ? colorScheme.primary : null,
        foregroundColor: neon ? colorScheme.onPrimary : null,
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

// ---------------------------------------------------------------------------
//  Exported themes
// ---------------------------------------------------------------------------
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

final ThemeData neonLightTheme = _buildTheme(
  colorScheme: _neonScheme(Brightness.light),
  neon: true,
);

final ThemeData neonDarkTheme = _buildTheme(
  colorScheme: _neonScheme(Brightness.dark),
  neon: true,
);
