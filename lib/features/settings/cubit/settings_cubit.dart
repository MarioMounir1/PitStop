import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torq/features/settings/cubit/settings_state.dart';

/// Persists user preferences (locale, theme, distance unit, currency) in
/// [SharedPreferences].
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._prefs) : super(_readInitialState(_prefs));

  static const String _keyLocale = 'torq_settings_locale';
  static const String _keyThemeMode = 'torq_settings_theme_mode';
  static const String _keyDistanceUnit = 'torq_settings_distance_unit';
  static const String _keyCurrencyCode = 'torq_settings_currency_code';

  static const List<String> supportedDistanceUnits = ['km', 'mi'];
  static const List<String> supportedCurrencies = ['EGP', 'SAR', 'AED', 'USD'];

  final SharedPreferences _prefs;

  static SettingsState _readInitialState(SharedPreferences prefs) {
    final langCode = prefs.getString(_keyLocale) ?? 'en';
    final themeStr = prefs.getString(_keyThemeMode) ?? 'dark';
    final distanceUnit = prefs.getString(_keyDistanceUnit) ?? 'km';
    final currencyCode = prefs.getString(_keyCurrencyCode) ?? 'EGP';

    return SettingsState(
      locale: Locale(langCode == 'ar' ? 'ar' : 'en'),
      themeMode: themeStr == 'light' ? ThemeMode.light : ThemeMode.dark,
      distanceUnit: supportedDistanceUnits.contains(distanceUnit)
          ? distanceUnit
          : 'km',
      currencyCode: supportedCurrencies.contains(currencyCode)
          ? currencyCode
          : 'EGP',
    );
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = locale.languageCode == 'ar' ? 'ar' : 'en';
    await _prefs.setString(_keyLocale, normalized);
    emit(state.copyWith(locale: Locale(normalized)));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final normalized = mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    await _prefs.setString(
      _keyThemeMode,
      normalized == ThemeMode.light ? 'light' : 'dark',
    );
    emit(state.copyWith(themeMode: normalized));
  }

  Future<void> setDistanceUnit(String unit) async {
    if (!supportedDistanceUnits.contains(unit)) return;
    await _prefs.setString(_keyDistanceUnit, unit);
    emit(state.copyWith(distanceUnit: unit));
  }

  Future<void> setCurrencyCode(String currency) async {
    final normalized = currency.toUpperCase();
    if (!supportedCurrencies.contains(normalized)) return;
    await _prefs.setString(_keyCurrencyCode, normalized);
    emit(state.copyWith(currencyCode: normalized));
  }
}
