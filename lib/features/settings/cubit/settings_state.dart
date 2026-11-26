import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.dark,
    this.distanceUnit = 'km',
    this.currencyCode = 'EGP',
    this.geminiApiKey = '',
  });

  final Locale locale;
  final ThemeMode themeMode;
  final String distanceUnit;
  final String currencyCode;
  final String geminiApiKey;

  bool get isArabic => locale.languageCode == 'ar';
  bool get isDark => themeMode == ThemeMode.dark;
  bool get hasGeminiApiKey => geminiApiKey.trim().isNotEmpty;

  SettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    String? distanceUnit,
    String? currencyCode,
    String? geminiApiKey,
  }) {
    return SettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      currencyCode: currencyCode ?? this.currencyCode,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }

  @override
  List<Object?> get props => [
        locale,
        themeMode,
        distanceUnit,
        currencyCode,
        geminiApiKey,
      ];
}
