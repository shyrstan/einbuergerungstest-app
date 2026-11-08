import 'package:flutter/material.dart';

/// App theme. [fontFamily]/[fontFamilyFallback] are only set when rendering
/// store screenshots in tests (devices use the system font).
ThemeData buildAppTheme({String? fontFamily, List<String>? fontFamilyFallback}) {
  const seed = Color(0xFF1F3A5F);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
    fontFamily: fontFamily,
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
      ),
    ),
  );
  if (fontFamilyFallback == null) return base;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: fontFamily, fontFamilyFallback: fontFamilyFallback),
  );
}
