import 'package:flutter/material.dart';

// ——— Premium brand palette (refined, Dribbble-style) ———

/// Primary: deep, confident blue (trust + action).
const Color appPrimaryGreen = Color(0xFF1E3A5F);

/// Lighter primary for highlights and interactive states.
const Color appPrimaryGreenLight = Color(0xFF2D5A87);

/// Soft tint for chips, tags, and card accents.
final Color appPrimaryGreenLightBg = const Color(0xFFE8F0F8).withOpacity(0.98);

/// Accent: fresh teal for charts, success, and focus.
const Color appAccentCyan = Color(0xFF0D9488);

/// Secondary accent for gradients and variety.
const Color appAccentWarm = Color(0xFFEA580C);

/// Surfaces: warm off-whites for depth and premium feel.
const Color appSurface = Color(0xFFF8FAFC);
const Color appSurfaceAlt = Color(0xFFF1F5F9);

/// Card and sheet backgrounds.
const Color appCardBg = Color(0xFFFFFFFF);

/// Primary text (headings, key content).
const Color appTextPrimary = Color(0xFF0F172A);

/// Muted text (captions, secondary).
const Color appTextMuted = Color(0xFF64748B);

/// Hero gradient for headers and CTAs.
const LinearGradient appHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF1E3A5F),
    Color(0xFF2D5A87),
    Color(0xFF0D9488),
  ],
);

/// Soft gradient for empty states and backgrounds.
const LinearGradient appSoftGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF8FAFC), Color(0xFFEEF2F7)],
);
