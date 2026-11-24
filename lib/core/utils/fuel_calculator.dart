import 'package:pitstop/core/database/app_database.dart';

/// Pure calculation utilities for fuel efficiency and cost-per-distance metrics.
abstract final class FuelCalculator {
  /// Calculates `consumptionKmPerL` for each log in [logs] across consecutive
  /// `isFullTank == true` entries.
  ///
  /// Any partial fills (`isFullTank == false`) between the previous full tank
  /// and the current full tank have their liters accumulated into the next full
  /// tank calculation:
  /// `kmPerL = (currentOdometer - prevFullTankOdometer) / (partialLiters + currentLiters)`.
  static Map<String, double?> calculateConsumptionMap(List<FuelLog> logs) {
    final sorted = List<FuelLog>.from(logs)
      ..sort((a, b) {
        final odoCompare = a.odometer.compareTo(b.odometer);
        if (odoCompare != 0) return odoCompare;
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

    final result = <String, double?>{};
    int? prevFullTankOdometer;
    double accumulatedPartialLiters = 0;

    for (final log in sorted) {
      if (log.isFullTank) {
        if (prevFullTankOdometer != null) {
          final distance = log.odometer - prevFullTankOdometer;
          final totalLiters = accumulatedPartialLiters + log.liters;
          if (distance > 0 && totalLiters > 0) {
            result[log.id] = distance / totalLiters;
          } else {
            result[log.id] = null;
          }
        } else {
          result[log.id] = null;
        }
        prevFullTankOdometer = log.odometer;
        accumulatedPartialLiters = 0;
      } else {
        if (prevFullTankOdometer != null && log.liters > 0) {
          accumulatedPartialLiters += log.liters;
        }
        result[log.id] = null;
      }
    }

    return result;
  }

  /// Converts `km/L` to `L/100km`. Returns `null` if [kmPerL] is not positive.
  static double? kmPerLToLitersPer100Km(double? kmPerL) {
    if (kmPerL == null || kmPerL <= 0) return null;
    return 100.0 / kmPerL;
  }

  /// Computes average `km/L` across all logs that have a positive consumption value.
  static double? averageKmPerL(List<FuelLog> logs) {
    final valid = logs
        .where((l) => l.consumptionKmPerL != null && l.consumptionKmPerL! > 0)
        .toList();
    if (valid.isEmpty) return null;
    final total = valid.fold<double>(0, (sum, l) => sum + l.consumptionKmPerL!);
    return total / valid.length;
  }

  /// Computes average cost per km (or distance unit).
  /// Returns `null` if [totalDistance] is not positive.
  static double? averageCostPerKm(double totalSpend, num totalDistance) {
    if (totalDistance <= 0) return null;
    return totalSpend / totalDistance;
  }
}
