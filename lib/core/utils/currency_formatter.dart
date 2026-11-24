import 'package:intl/intl.dart';

/// Locale-aware currency formatting utility for Torq.
abstract final class CurrencyFormatter {
  static const Map<String, String> _symbols = <String, String>{
    'EGP': 'EGP',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'SAR': 'SAR',
    'AED': 'AED',
    'KWD': 'KWD',
    'QAR': 'QAR',
  };

  /// Formats [amount] using the given ISO 4217 [currencyCode] (default `EGP`).
  static String format(
    num amount, {
    String currencyCode = 'EGP',
    String? locale,
    int decimalDigits = 2,
  }) {
    final code = currencyCode.toUpperCase();
    final symbol = _symbols[code] ?? code;
    final hasTrailingCode = symbol == code;

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: hasTrailingCode ? '' : symbol,
      decimalDigits: decimalDigits,
    );

    final formatted = formatter.format(amount).trim();
    return hasTrailingCode ? '$formatted $code' : formatted;
  }

  /// Formats [amount] in compact notation (e.g., `12.5K EGP`).
  static String formatCompact(
    num amount, {
    String currencyCode = 'EGP',
    String? locale,
  }) {
    final code = currencyCode.toUpperCase();
    final symbol = _symbols[code] ?? code;
    final hasTrailingCode = symbol == code;

    final compact = NumberFormat.compact(locale: locale).format(amount);
    return hasTrailingCode ? '$compact $code' : '$symbol$compact';
  }
}
