import 'package:flutter/material.dart';

/// PitStop color tokens for both the signature Dark Automotive M3 palette
/// and the clean Light palette.
abstract final class AppColors {
  // Brand & Semantic Colors (shared)
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);

  static const Color ok = Color(0xFF10B981);
  static const Color dueSoon = Color(0xFFF59E0B);
  static const Color overdue = Color(0xFFEF4444);

  // Dark Automotive Palette
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkCard = Color(0xFF141A26);
  static const Color darkElevated = Color(0xFF1E2638);
  static const Color darkBorder = Color(0xFF28334A);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Clean Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF1F5F9);
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
    border: AppColors.lightBorder,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextMuted,
    ok: AppColors.ok,
    dueSoon: AppColors.dueSoon,
    overdue: AppColors.overdue,
  );

  final Color background;
  final Color card;
  final Color elevated;
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
