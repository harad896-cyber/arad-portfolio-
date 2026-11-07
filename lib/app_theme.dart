import 'package:flutter/material.dart';

/// Semantic color tokens shared by GapResan surfaces and feature pages.
///
/// This first foundation step intentionally preserves the current appearance;
/// widgets can migrate from hard-coded colors to these semantic roles gradually.
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
  }) {
    if (dark) {
      const canvas = Color(0xFF071A13);
      return GapResanThemeTokens(
        canvas: canvas,
        surface: const Color(0xFF0D251A),
        elevatedSurface: const Color(0xFF123322),
        subtleSurface: const Color(0xFF0B2016),
        textPrimary: const Color(0xFFF4F2FA),
        textSecondary: const Color(0xFFA6B9AC),
        divider: const Color(0xFF294234),
        accent: accent,
        accentSoft: accent.withValues(alpha: .16),
        outgoingBubble: Color.lerp(accent, canvas, .34)!,
        incomingBubble: const Color(0xFF10291D),
        chatBackdrop: canvas,
        danger: const Color(0xFFFF8A8A),
      );
    }

    const canvas = Color(0xFFF4F8F5);
    return GapResanThemeTokens(
      canvas: canvas,
      surface: const Color(0xFFFFFFFF),
      elevatedSurface: const Color(0xFFFCFCFE),
      subtleSurface: const Color(0xFFEDF4EF),
      textPrimary: const Color(0xFF171320),
      textSecondary: const Color(0xFF647268),
      divider: const Color(0xFFDDE8E0),
      accent: accent,
      accentSoft: accent.withValues(alpha: .12),
      outgoingBubble: Color.lerp(accent, Colors.white, .12)!,
      incomingBubble: const Color(0xFFFFFFFF),
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
    Color? canvas, Color? surface, Color? elevatedSurface,
    Color? subtleSurface, Color? textPrimary, Color? textSecondary,
    Color? divider, Color? accent, Color? accentSoft,
    Color? outgoingBubble, Color? incomingBubble, Color? chatBackdrop,
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
