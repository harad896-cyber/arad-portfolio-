import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/app_theme.dart';

void main() {
  group('GapResanThemeTokens', () {
    test('provides semantic colors for dark and light themes', () {
      final dark = GapResanThemeTokens.forBrightness(dark: true, accent: const Color(0xFF00C2A8));
      final light = GapResanThemeTokens.forBrightness(dark: false, accent: const Color(0xFF00C2A8));
      expect(dark.canvas, const Color(0xFF071A2D));
      expect(dark.incomingBubble, const Color(0xFF0D2336));
      expect(dark.accent, const Color(0xFF00C2A8));
      expect(light.canvas, const Color(0xFFF6F7FB));
      expect(light.surface, Colors.white);
    });

    test('maps saved appearance modes to Flutter theme modes', () {
      expect(gapResanThemeMode('dark'), ThemeMode.dark);
      expect(gapResanThemeMode('light'), ThemeMode.light);
      expect(gapResanThemeMode('system'), ThemeMode.system);
      expect(gapResanThemeMode('unknown'), ThemeMode.dark);
    });

    test('resolves system brightness while preserving explicit modes', () {
      expect(gapResanResolveDarkMode('system', Brightness.dark), isTrue);
      expect(gapResanResolveDarkMode('system', Brightness.light), isFalse);
      expect(gapResanResolveDarkMode('dark', Brightness.light), isTrue);
      expect(gapResanResolveDarkMode('light', Brightness.dark), isFalse);
    });

    test('copyWith changes only the requested token', () {
      final original = GapResanThemeTokens.forBrightness(dark: true, accent: const Color(0xFF00C2A8));
      final updated = original.copyWith(surface: const Color(0xFF123456));
      expect(updated.surface, const Color(0xFF123456));
      expect(updated.canvas, original.canvas);
      expect(updated.accent, original.accent);
    });

    test('lerp interpolates token colors', () {
      final start = GapResanThemeTokens.forBrightness(dark: true, accent: Colors.black);
      final end = start.copyWith(accent: Colors.white);
      expect(start.lerp(end, 0.5).accent.r, 0.5);
    });
  });
}
