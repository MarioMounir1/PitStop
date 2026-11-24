import 'package:equatable/equatable.dart';

/// Represents a default vehicle maintenance schedule preset.
class MaintenancePreset extends Equatable {
  const MaintenancePreset({
    required this.category,
    required this.defaultIntervalKm,
    required this.defaultIntervalMonths,
  });

  /// Canonical category key stored in `MaintenanceRecords.category`.
  final String category;

  /// Recommended distance interval in kilometers (`0` when time-only, e.g. battery).
  final int defaultIntervalKm;

  /// Recommended time interval in months.
  final int defaultIntervalMonths;

  bool get hasDistanceInterval => defaultIntervalKm > 0;
  bool get hasTimeInterval => defaultIntervalMonths > 0;

  @override
  List<Object?> get props => [
        category,
        defaultIntervalKm,
        defaultIntervalMonths,
      ];
}

/// Built-in maintenance presets shared across onboarding, logging, and reminders.
abstract final class MaintenancePresets {
  static const String engineOil = 'engine_oil';
  static const String oilFilter = 'oil_filter';
  static const String airFilter = 'air_filter';
  static const String acFilter = 'ac_filter';
  static const String brakePads = 'brake_pads';
  static const String tires = 'tires';
  static const String battery = 'battery';
  static const String timingBelt = 'timing_belt';
  static const String sparkPlugs = 'spark_plugs';
  static const String transmissionOil = 'transmission_oil';

  static const List<MaintenancePreset> defaults = <MaintenancePreset>[
    MaintenancePreset(
      category: engineOil,
      defaultIntervalKm: 10000,
      defaultIntervalMonths: 6,
    ),
    MaintenancePreset(
      category: oilFilter,
      defaultIntervalKm: 10000,
      defaultIntervalMonths: 6,
    ),
    MaintenancePreset(
      category: airFilter,
      defaultIntervalKm: 20000,
      defaultIntervalMonths: 12,
    ),
    MaintenancePreset(
      category: acFilter,
      defaultIntervalKm: 15000,
      defaultIntervalMonths: 12,
    ),
    MaintenancePreset(
      category: brakePads,
      defaultIntervalKm: 40000,
      defaultIntervalMonths: 24,
    ),
    MaintenancePreset(
      category: tires,
      defaultIntervalKm: 60000,
      defaultIntervalMonths: 48,
    ),
    MaintenancePreset(
      category: battery,
      defaultIntervalKm: 0,
      defaultIntervalMonths: 24,
    ),
    MaintenancePreset(
      category: timingBelt,
      defaultIntervalKm: 60000,
      defaultIntervalMonths: 60,
    ),
    MaintenancePreset(
      category: sparkPlugs,
      defaultIntervalKm: 40000,
      defaultIntervalMonths: 36,
    ),
    MaintenancePreset(
      category: transmissionOil,
      defaultIntervalKm: 60000,
      defaultIntervalMonths: 48,
    ),
  ];

  static MaintenancePreset? byCategory(String category) {
    for (final preset in defaults) {
      if (preset.category == category) return preset;
    }
    return null;
  }
}
