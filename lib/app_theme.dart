import 'package:flutter/material.dart';

/// Semantic color roles shared by the whole GapResan interface.
/// Palette surfaces are derived from the selected background so presets
/// affect real screens, not only the theme picker preview.
@immutable
class GapResanThemeTokens extends ThemeExtension<GapResanThemeTokens> {
  const GapResanThemeTokens({
    required this.canvas,
    required this.surface,
    required this.elevatedSurface,
    required this.subtleSurface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.accent,
    required this.accentSoft,
    required this.outgoingBubble,
    required this.incomingBubble,
    required this.chatBackdrop,
    required this.danger,
  });

  factory GapResanThemeTokens.forBrightness({
    required bool dark,
    required Color accent,
    int backgroundSeed = 0xFF081712,
  }) {
    final selectedBackground = Color(backgroundSeed);
    final luminance = selectedBackground.computeLuminance();
    final matchesBrightness = dark ? luminance < .42 : luminance > .58;

    if (dark) {
      final canvas = matchesBrightness
          ? selectedBackground
          : const Color(0xFF081712);
      final surface = Color.lerp(canvas, Colors.white, .075)!;
      final elevated = Color.lerp(canvas, Colors.white, .12)!;
      return GapResanThemeTokens(
        canvas: canvas,
        surface: surface,
        elevatedSurface: elevated,
        subtleSurface: Color.lerp(canvas, Colors.white, .045)!,
        textPrimary: const Color(0xFFF7FBF8),
        textSecondary: const Color(0xFFB4C6BC),
        divider: Color.lerp(canvas, Colors.white, .19)!,
        accent: accent,
        accentSoft: accent.withValues(alpha: .16),
        outgoingBubble: Color.lerp(accent, canvas, .34)!,
        incomingBubble: Color.lerp(surface, canvas, .30)!,
        chatBackdrop: canvas,
        danger: const Color(0xFFFF8A8A),
      );
    }

    final canvas = matchesBrightness
        ? selectedBackground
        : const Color(0xFFF5F8F6);
    final surface = Color.lerp(canvas, Colors.white, .72)!;
    return GapResanThemeTokens(
      canvas: canvas,
      surface: surface,
      elevatedSurface: Colors.white,
      subtleSurface: Color.lerp(canvas, Colors.white, .48)!,
      textPrimary: const Color(0xFF17231C),
      textSecondary: const Color(0xFF65756B),
      divider: Color.lerp(canvas, Colors.black, .10)!,
      accent: accent,
      accentSoft: accent.withValues(alpha: .12),
      // Darken the outgoing bubble in light mode to keep white message text
      // legible even when the selected accent is bright gold or yellow.
      outgoingBubble: Color.lerp(accent, Colors.black, .25)!,
      incomingBubble: surface,
      chatBackdrop: canvas,
      danger: const Color(0xFFB42318),
    );
  }

  final Color canvas;
  final Color surface;
  final Color elevatedSurface;
  final Color subtleSurface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color accent;
  final Color accentSoft;
  final Color outgoingBubble;
  final Color incomingBubble;
  final Color chatBackdrop;
  final Color danger;

  @override
  GapResanThemeTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? elevatedSurface,
    Color? subtleSurface,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? accent,
    Color? accentSoft,
    Color? outgoingBubble,
    Color? incomingBubble,
    Color? chatBackdrop,
    Color? danger,
  }) => GapResanThemeTokens(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    subtleSurface: subtleSurface ?? this.subtleSurface,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    divider: divider ?? this.divider,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    outgoingBubble: outgoingBubble ?? this.outgoingBubble,
    incomingBubble: incomingBubble ?? this.incomingBubble,
    chatBackdrop: chatBackdrop ?? this.chatBackdrop,
    danger: danger ?? this.danger,
  );

  @override
  GapResanThemeTokens lerp(
    covariant ThemeExtension<GapResanThemeTokens>? other,
    double t,
  ) {
    if (other is! GapResanThemeTokens) return this;
    return GapResanThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      chatBackdrop: Color.lerp(chatBackdrop, other.chatBackdrop, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
