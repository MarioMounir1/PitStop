import 'package:flutter/material.dart';
import 'package:torq/core/theme/app_colors.dart';

/// Material 3 theme builder for Torq.
/// Automatically switches font family to `Cairo` for Arabic locales
/// and `Plus Jakarta Sans` for English / other locales.
abstract final class AppTheme {
  static const String arabicFontFamily = 'Cairo';
  static const String englishFontFamily = 'Plus Jakarta Sans';

  static String fontFamilyForLocale(Locale? locale) {
    if (locale?.languageCode.toLowerCase() == 'ar') {
      return arabicFontFamily;
    }
    return englishFontFamily;
  }

  static ThemeData dark({Locale? locale}) {
    final fontFamily = fontFamilyForLocale(locale);
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF1D3B6E),
      onPrimaryContainer: Color(0xFFDBEAFE),
      secondary: AppColors.ok,
      onSecondary: Color(0xFF042F2E),
      secondaryContainer: Color(0xFF064E3B),
      onSecondaryContainer: Color(0xFFD1FAE5),
      tertiary: AppColors.dueSoon,
      onTertiary: Color(0xFF451A03),
      error: AppColors.overdue,
      onError: Colors.white,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: AppColors.darkCard,
      surfaceContainer: AppColors.darkElevated,
      surfaceContainerHigh: AppColors.darkElevated,
      surfaceContainerHighest: Color(0xFF253047),
      outline: AppColors.darkBorder,
      outlineVariant: Color(0xFF1E293B),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      palette: AppColorExtension.dark,
      fontFamily: fontFamily,
    );
  }

  static ThemeData light({Locale? locale}) {
    final fontFamily = fontFamilyForLocale(locale);
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDBEAFE),
      onPrimaryContainer: Color(0xFF1E3A8A),
      secondary: AppColors.ok,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD1FAE5),
      onSecondaryContainer: Color(0xFF064E3B),
      tertiary: AppColors.dueSoon,
      onTertiary: Colors.white,
      error: AppColors.overdue,
      onError: Colors.white,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      surfaceContainerLowest: AppColors.lightCard,
      surfaceContainerLow: AppColors.lightBackground,
      surfaceContainer: AppColors.lightElevated,
      surfaceContainerHigh: AppColors.lightElevated,
      surfaceContainerHighest: Color(0xFFE2E8F0),
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFF1F5F9),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      palette: AppColorExtension.light,
      fontFamily: fontFamily,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required AppColorExtension palette,
    required String fontFamily,
  }) {
    final baseTextTheme = colorScheme.brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final textTheme = baseTextTheme.apply(
      fontFamily: fontFamily,
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      fontFamily: fontFamily,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.overdue),
        ),
        labelStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.card,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primary : palette.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.primary : palette.textSecondary,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.elevated,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.elevated,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: palette.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.border),
        ),
      ),
    );
  }
}
