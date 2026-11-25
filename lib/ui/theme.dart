// Copyright (c) 2026 Cave. See AUTHORS.md.
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';

import '../domain/library.dart';

/// Cave design-system colours, matching the Cave POS Flutter adapter
/// (`lib/app/theme.dart`): Light, standard Dark and the near-black Black theme.
/// Buttons are rectangular with a 10px radius in every theme.
class PaperTheme {
  PaperTheme._();

  static const lagoon = Color(0xFF047283); // Light action fill
  static const teal = Color(0xFF179D9F); // brand teal; Black action fill
  static const ink = Color(0xFF182643); // brand navy text
  static const paper = Color(0xFFF8F8F8); // Light page
  static const darkPage = Color(0xFF10252D);
  static const darkRaised = Color(0xFF19333C);
  static const darkInk = Color(0xFFE3F4F5);
  static const darkBorder = Color(0xFF38545D);
  static const aqua = Color(0xFF51DED4); // Dark action fill
  static const charcoal = Color(0xFF1D1D1B); // Black page, never pure black
  static const blackRaised = Color(0xFF2B2B29);

  static const radiusButton = 10.0;
  static const radiusCard = 14.0;

  static ColorScheme scheme(Appearance palette) => switch (palette) {
    Appearance.dark =>
      ColorScheme.fromSeed(
        seedColor: aqua,
        brightness: Brightness.dark,
      ).copyWith(
        primary: aqua,
        onPrimary: darkPage,
        surface: darkPage,
        onSurface: darkInk,
        surfaceContainerLowest: darkPage,
        surfaceContainerLow: darkRaised,
        surfaceContainer: darkRaised,
        surfaceContainerHigh: const Color(0xFF203D47),
        surfaceContainerHighest: const Color(0xFF284852),
        outline: darkBorder,
      ),
    Appearance.black =>
      ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.dark,
      ).copyWith(
        primary: teal,
        onPrimary: charcoal,
        surface: charcoal,
        onSurface: const Color(0xFFF2F2F0),
        surfaceContainerLowest: charcoal,
        surfaceContainerLow: blackRaised,
        surfaceContainer: blackRaised,
        surfaceContainerHigh: const Color(0xFF343432),
        surfaceContainerHighest: const Color(0xFF3D3D3A),
        outline: const Color(0xFF5A5A56),
      ),
    _ => ColorScheme.fromSeed(seedColor: lagoon).copyWith(
      primary: lagoon,
      onPrimary: Colors.white,
      surface: paper,
      onSurface: ink,
    ),
  };

  /// [palette] is Light, Dark or Black; System is resolved by the caller.
  static ThemeData build(Appearance palette, {required String language}) {
    final colors = scheme(palette);
    const button = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radiusButton)),
    );
    final buttonStyle = ButtonStyle(
      shape: const WidgetStatePropertyAll(button),
      minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: language == 'ar' ? 'IBMPlexSansArabic' : 'IBMPlexSans',
      scaffoldBackgroundColor: colors.surface,
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(button)),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(button)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusCard)),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusButton)),
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
