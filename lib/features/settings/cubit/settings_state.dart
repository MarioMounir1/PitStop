import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.dark,
    this.distanceUnit = 'km',
    this.currencyCode = 'EGP',
  });

  final Locale locale;
  final ThemeMode themeMode;
  final String distanceUnit;
  final String currencyCode;

  bool get isArabic => locale.languageCode == 'ar';
  bool get isDark => themeMode == ThemeMode.dark;

  SettingsState copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    String? distanceUnit,
    String? currencyCode,
  }) {
    return SettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }

  @override
  List<Object?> get props => [locale, themeMode, distanceUnit, currencyCode];
}
