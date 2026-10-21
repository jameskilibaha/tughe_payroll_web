import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/persistence_service.dart';

/// Whether the UI is currently dark. Set by [ThemeProvider]; read by [Pal] so
/// helper methods that have no BuildContext can still pick the right colors.
bool appIsDark = false;

/// Approximates the Tailwind slate/blue palette used across the original
/// React UI (bg-slate-100, text-slate-900, selection:bg-blue-600, etc.).
class AppColors {
  static const primaryBlue = Color(0xFF2563EB); // blue-600
  static const darkBlue = Color(0xFF1D4ED8); // blue-700
  static const brandBlue = Color(0xFF1E3A8A); // blue-900 (headers, sidebar, primary buttons)
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate600 = Color(0xFF475569);
  static const slate900 = Color(0xFF0F172A);
  static const success = Color(0xFF16A34A); // green-600
  static const danger = Color(0xFFDC2626); // red-600
  static const warning = Color(0xFFD97706); // amber-600
  static const gold = Color(0xFFF2B134); // the TUGHE "stamp" accent: selection, highlights

  // Dark-mode surface colors
  static const darkSurface = Color(0xFF1E293B); // slate-800
  static const darkSurfaceAlt = Color(0xFF273449); // between slate-800 and slate-700
  static const darkBackground = Color(0xFF0F172A); // slate-900
  static const darkBorder = Color(0xFF334155); // slate-700
}

/// Semantic colors that follow the current theme. Use these instead of
/// hard-coding `Colors.white`, `Colors.black54`, `Color(0xFFE2E8F0)` ... so a
/// screen looks right in BOTH light and dark mode.
///
///   surface      cards, panels, table backgrounds
///   surfaceAlt   subtle fills (table headings, bar tracks, zebra rows)
///   border       card/table borders and dividers
///   text         main text            textSecondary / textMuted  weaker text
///   brandText    the brand blue when used as TEXT/ICON colour on a surface
///   tint(x)      the light background of a coloured banner/chip
///   fg(x)        a strong colour (e.g. green.shade700) kept readable on dark
class Pal {
  Pal._();

  static bool get dark => appIsDark;

  static Color get surface => dark ? AppColors.darkSurface : Colors.white;
  static Color get surfaceAlt => dark ? AppColors.darkSurfaceAlt : const Color(0xFFF1F5F9);
  static Color get border => dark ? AppColors.darkBorder : AppColors.slate200;
  static Color get text => dark ? const Color(0xFFE2E8F0) : AppColors.slate900;
  static Color get textSecondary => dark ? const Color(0xFFCBD5E1) : Colors.black54;
  static Color get textMuted => dark ? const Color(0xFF94A3B8) : Colors.black45;
  static Color get brandText => dark ? const Color(0xFF93C5FD) : AppColors.brandBlue;

  /// The main action colour: buttons, focus rings, switches, selected controls.
  static Color get primary => dark ? const Color(0xFF60A5FA) : AppColors.brandBlue;
  static Color get onPrimary => dark ? const Color(0xFF0B1220) : Colors.white;

  /// Background of a text field (slightly off the card so a field is visible on it).
  static Color get fieldFill => dark ? const Color(0xFF172033) : AppColors.slate50;
  static Color get fieldBorder => dark ? const Color(0xFF475569) : AppColors.slate300;
  static Color get danger => dark ? const Color(0xFFF87171) : AppColors.danger;
  static Color get success => dark ? const Color(0xFF4ADE80) : AppColors.success;

  /// Blue used for chart bars/slices: bright enough on the dark surface too.
  static Color get chartBlue => dark ? const Color(0xFF60A5FA) : AppColors.primaryBlue;

  /// Background of a coloured banner/chip: pastel in light mode, a soft
  /// transparent wash of the same hue in dark mode.
  static Color tint(Color c) {
    if (!dark) return c is MaterialColor ? c.shade50 : c.withOpacity(0.08);
    return c.withOpacity(0.16);
  }

  /// A strong foreground colour; lightened in dark mode so it stays readable.
  static Color fg(Color c) {
    if (!dark) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.28).clamp(0.0, 0.8)).toColor();
  }
}

/// Provider-managed theme toggle (light/dark), independent of the GetX
/// controllers used for business/domain state. Starts LIGHT
/// and then remembers the user's explicit choice.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({PersistenceService? persistence}) : _persistence = persistence ?? PersistenceService() {
    _mode = ThemeMode.light; // default is always LIGHT; only an explicit user choice switches it
    appIsDark = false;
    _restore();
  }

  static const _key = 'tughe_theme_mode';

  final PersistenceService _persistence;
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _restore() async {
    final saved = await _persistence.readJson(_key);
    final next = saved == 'dark'
        ? ThemeMode.dark
        : saved == 'light'
            ? ThemeMode.light
            : null; // nothing saved: stay on light
    if (next != null && next != _mode) {
      _mode = next;
      appIsDark = isDark;
      notifyListeners();
    }
  }

  void toggle() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    appIsDark = isDark;
    notifyListeners();
    unawaited(_persistence.writeJson(_key, _mode == ThemeMode.dark ? 'dark' : 'light'));
  }
}

ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

/// ONE theme for both modes, so every text field, form, button, switch, chip and menu in the app
/// looks the same everywhere: fields are filled and rounded with a clear blue focus ring and a
/// red error state; buttons share a height, shape and weight; the brand blue is the one action
/// colour (a lighter blue on the dark surface), with the gold "stamp" only for selection.
ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final primary = dark ? const Color(0xFF60A5FA) : AppColors.brandBlue;
  final onPrimary = dark ? const Color(0xFF0B1220) : Colors.white;
  final surface = dark ? AppColors.darkSurface : Colors.white;
  final background = dark ? AppColors.darkBackground : AppColors.slate100;
  final border = dark ? AppColors.darkBorder : AppColors.slate200;
  final fieldBorder = dark ? const Color(0xFF475569) : AppColors.slate300;
  final fieldFill = dark ? const Color(0xFF172033) : AppColors.slate50;
  final text = dark ? const Color(0xFFE2E8F0) : AppColors.slate900;
  final muted = dark ? const Color(0xFF94A3B8) : AppColors.slate600;
  final hint = dark ? const Color(0xFF64748B) : AppColors.slate400;
  final danger = dark ? const Color(0xFFF87171) : AppColors.danger;

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primaryBlue, brightness: brightness, surface: surface).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    error: danger,
    outline: fieldBorder,
    outlineVariant: border,
    surfaceContainerHigh: surface, // dialogs and menus use the card colour
    surfaceContainerHighest: dark ? AppColors.darkSurfaceAlt : AppColors.slate100,
  );

  OutlineInputBorder fieldOutline(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
  const buttonText = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.2);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    fontFamily: 'Roboto',
    dividerColor: border,
    hoverColor: primary.withOpacity(0.06),
    focusColor: primary.withOpacity(0.12),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

    // ---- text fields and drop-downs ----
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      hoverColor: dark ? const Color(0xFF1B2740) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: fieldOutline(fieldBorder),
      enabledBorder: fieldOutline(fieldBorder),
      focusedBorder: fieldOutline(primary, 2),
      errorBorder: fieldOutline(danger, 1.2),
      focusedErrorBorder: fieldOutline(danger, 2),
      disabledBorder: fieldOutline(border),
      labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.error) ? danger : primary,
            fontWeight: FontWeight.w700,
          )),
      hintStyle: TextStyle(color: hint, fontWeight: FontWeight.w400),
      helperStyle: TextStyle(color: muted, fontSize: 11),
      helperMaxLines: 2,
      errorStyle: TextStyle(color: danger, fontSize: 11.5, fontWeight: FontWeight.w600),
      errorMaxLines: 2,
      prefixIconColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.focused) ? primary : muted),
      suffixIconColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.focused) ? primary : muted),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: AppColors.gold.withOpacity(0.35),
      selectionHandleColor: primary,
    ),

    // ---- buttons ----
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: dark ? AppColors.darkBorder : AppColors.slate200,
        disabledForegroundColor: hint,
        elevation: 0,
        minimumSize: const Size(64, 40),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: dark ? AppColors.darkBorder : AppColors.slate200,
        disabledForegroundColor: hint,
        minimumSize: const Size(64, 40),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: hint,
        side: BorderSide(color: fieldBorder, width: 1.2),
        minimumSize: const Size(64, 40),
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: hint,
        minimumSize: const Size(48, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: buttonText,
      ),
    ),

    // ---- switches, boxes, chips, menus ----
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? onPrimary : (dark ? const Color(0xFF94A3B8) : Colors.white)),
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primary : (dark ? const Color(0xFF334155) : AppColors.slate300)),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primary : null),
      checkColor: WidgetStatePropertyAll(onPrimary),
      side: BorderSide(color: fieldBorder, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? primary : fieldBorder),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fieldFill,
      selectedColor: primary.withOpacity(dark ? 0.28 : 0.14),
      checkmarkColor: primary,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: text),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: border)),
      textStyle: TextStyle(fontSize: 12.5, color: text),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(hint.withOpacity(0.55)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(7),
    ),
    dataTableTheme: DataTableThemeData(
      dividerThickness: 0.8,
      headingTextStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: text),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF475569).withOpacity(0.95) : AppColors.slate900.withOpacity(0.92),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}
