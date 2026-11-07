import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/app_theme.dart';

void main() {
  group('GapResanThemeTokens', () {
    test('provides semantic colors for dark and light themes', () {
      const accent = Color(0xFF0B9658);
      final dark = GapResanThemeTokens.forBrightness(dark: true, accent: accent);
      final light = GapResanThemeTokens.forBrightness(dark: false, accent: accent);
      expect(dark.canvas, const Color(0xFF071A13));
      expect(dark.incomingBubble, const Color(0xFF10291D));
      expect(dark.accent, accent);
      expect(light.canvas, const Color(0xFFF4F8F5));
      expect(light.surface, Colors.white);
    });

    test('copyWith changes only the requested token', () {
      final original = GapResanThemeTokens.forBrightness(
        dark: true,
        accent: const Color(0xFF0B9658),
      );
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
