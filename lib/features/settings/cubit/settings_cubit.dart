import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pitstop/features/settings/cubit/settings_state.dart';

/// Persists user preferences (locale, theme, distance unit, currency, Gemini key)
/// in [SharedPreferences], with automatic `.env` discovery on desktop dev builds.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._prefs) : super(_readInitialState(_prefs));

  static const String keyLocale = 'pitstop_settings_locale';
  static const String keyThemeMode = 'pitstop_settings_theme_mode';
  static const String keyDistanceUnit = 'pitstop_settings_distance_unit';
  static const String keyCurrencyCode = 'pitstop_settings_currency_code';
  static const String keyGeminiApiKey = 'pitstop_settings_gemini_api_key';

  static const List<String> supportedDistanceUnits = ['km', 'mi'];
  static const List<String> supportedCurrencies = ['EGP', 'SAR', 'AED', 'USD'];

  final SharedPreferences _prefs;

  static String resolveStoredOrEnvGeminiKey(SharedPreferences prefs) {
    final stored = prefs.getString(keyGeminiApiKey)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;

    const dartDefineKey = String.fromEnvironment('GEMINI_API_KEY');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    if (!kIsWeb) {
      for (final candidate in ['.env', 'backend/.env']) {
        try {
          final file = File(candidate);
          if (file.existsSync()) {
            for (final line in file.readAsLinesSync()) {
              final trimmed = line.trim();
              if (trimmed.startsWith('GEMINI_API_KEY=')) {
                final val = trimmed
                    .substring('GEMINI_API_KEY='.length)
                    .trim()
                    .replaceAll('"', '')
                    .replaceAll("'", '');
                if (val.isNotEmpty && val != 'your-gemini-api-key') {
                  return val;
                }
              }
            }
          }
        } catch (_) {
          // Ignore file system errors on restricted sandboxes.
        }
      }
    }
    return '';
  }

  static SettingsState _readInitialState(SharedPreferences prefs) {
    final langCode = prefs.getString(keyLocale) ?? 'en';
    final themeStr = prefs.getString(keyThemeMode) ?? 'dark';
    final distanceUnit = prefs.getString(keyDistanceUnit) ?? 'km';
    final currencyCode = prefs.getString(keyCurrencyCode) ?? 'EGP';
    final geminiKey = resolveStoredOrEnvGeminiKey(prefs);

    return SettingsState(
      locale: Locale(langCode == 'ar' ? 'ar' : 'en'),
      themeMode: themeStr == 'light' ? ThemeMode.light : ThemeMode.dark,
      distanceUnit: supportedDistanceUnits.contains(distanceUnit)
          ? distanceUnit
          : 'km',
      currencyCode: supportedCurrencies.contains(currencyCode)
          ? currencyCode
          : 'EGP',
      geminiApiKey: geminiKey,
    );
  }

  Future<void> setLocale(Locale locale) async {
    final normalized = locale.languageCode == 'ar' ? 'ar' : 'en';
    await _prefs.setString(keyLocale, normalized);
    emit(state.copyWith(locale: Locale(normalized)));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final normalized =
        mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    await _prefs.setString(
      keyThemeMode,
      normalized == ThemeMode.light ? 'light' : 'dark',
    );
    emit(state.copyWith(themeMode: normalized));
  }

  Future<void> setDistanceUnit(String unit) async {
    if (!supportedDistanceUnits.contains(unit)) return;
    await _prefs.setString(keyDistanceUnit, unit);
    emit(state.copyWith(distanceUnit: unit));
  }

  Future<void> setCurrencyCode(String currency) async {
    final normalized = currency.toUpperCase();
    if (!supportedCurrencies.contains(normalized)) return;
    await _prefs.setString(keyCurrencyCode, normalized);
    emit(state.copyWith(currencyCode: normalized));
  }

  Future<void> setGeminiApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await _prefs.remove(keyGeminiApiKey);
    } else {
      await _prefs.setString(keyGeminiApiKey, trimmed);
    }
    emit(state.copyWith(geminiApiKey: trimmed));
  }
}
