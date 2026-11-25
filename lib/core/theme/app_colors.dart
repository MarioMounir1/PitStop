import 'package:flutter/material.dart';

/// PitStop color tokens for the signature Dark Amber Automotive palette
/// and harmonized Light palette.
abstract final class AppColors {
  // Brand & Semantic Colors
  static const Color primary = Color(0xFFFFAE19);
  static const Color primaryDark = Color(0xFFE59400);
  static const Color primaryLight = Color(0xFFFFC452);
  static const Color onPrimary = Color(0xFF111315);

  static const Color ok = Color(0xFF34D399);
  static const Color dueSoon = Color(0xFFFBBF24);
  static const Color overdue = Color(0xFFF87171);

  // Tinted pill backgrounds (Dark)
  static const Color okSurfaceDark = Color(0xFF102E22);
  static const Color dueSoonSurfaceDark = Color(0xFF33250E);
  static const Color overdueSurfaceDark = Color(0xFF3B181B);

  // Analytics stacked chart palette
  static const Color chartFuel = Color(0xFFFFAE19);
  static const Color chartMaintenance = Color(0xFF22A699);
  static const Color chartOther = Color(0xFF525E75);

  // Dark Obsidian Automotive Palette
  static const Color darkBackground = Color(0xFF0B0D10);
  static const Color darkCard = Color(0xFF141820);
  static const Color darkElevated = Color(0xFF1C212B);
  static const Color darkInput = Color(0xFF0E1116);
  static const Color darkBorder = Color(0xFF232936);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF8E96A4);
  static const Color darkTextMuted = Color(0xFF5D6574);

  // Clean Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF1F5F9);
  static const Color lightInput = Color(0xFFF8FAFC);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
}

/// Theme extension exposing semantic and surface colors via `Theme.of(context)`.
@immutable
class AppColorExtension extends ThemeExtension<AppColorExtension> {
  const AppColorExtension({
    required this.background,
    required this.card,
    required this.elevated,
    required this.inputFill,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.ok,
    required this.dueSoon,
    required this.overdue,
  });

  static const AppColorExtension dark = AppColorExtension(
    background: AppColors.darkBackground,
    card: AppColors.darkCard,
    elevated: AppColors.darkElevated,
    inputFill: AppColors.darkInput,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    ok: AppColors.ok,
    dueSoon: AppColors.dueSoon,
    overdue: AppColors.overdue,
  );

  static const AppColorExtension light = AppColorExtension(
    background: AppColors.lightBackground,
    card: AppColors.lightCard,
    elevated: AppColors.lightElevated,
    inputFill: AppColors.lightInput,
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    ok: Color(0xFF059669),
    dueSoon: Color(0xFFD97706),
    overdue: Color(0xFFDC2626),
  );

  final Color background;
  final Color card;
  final Color elevated;
  final Color inputFill;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color ok;
  final Color dueSoon;
  final Color overdue;

  @override
  AppColorExtension copyWith({
    Color? background,
    Color? card,
    Color? elevated,
    Color? inputFill,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? ok,
    Color? dueSoon,
    Color? overdue,
  }) {
    return AppColorExtension(
      background: background ?? this.background,
      card: card ?? this.card,
      elevated: elevated ?? this.elevated,
      inputFill: inputFill ?? this.inputFill,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      ok: ok ?? this.ok,
      dueSoon: dueSoon ?? this.dueSoon,
      overdue: overdue ?? this.overdue,
    );
  }

  @override
  AppColorExtension lerp(ThemeExtension<AppColorExtension>? other, double t) {
    if (other is! AppColorExtension) return this;
    return AppColorExtension(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      dueSoon: Color.lerp(dueSoon, other.dueSoon, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColorExtension get appColors =>
      Theme.of(this).extension<AppColorExtension>() ?? AppColorExtension.dark;
}
