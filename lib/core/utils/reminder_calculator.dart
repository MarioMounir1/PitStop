import 'package:pitstop/core/widgets/status_chip.dart';

/// Health status of a maintenance item or scheduled service.
enum MaintenanceStatus {
  ok,
  dueSoon,
  overdue;

  StatusChipType toChipType() {
    return switch (this) {
      MaintenanceStatus.ok => StatusChipType.ok,
      MaintenanceStatus.dueSoon => StatusChipType.dueSoon,
      MaintenanceStatus.overdue => StatusChipType.overdue,
    };
  }
}

/// Pure business-logic calculator for maintenance & document due statuses.
abstract final class ReminderCalculator {
  static const int dueSoonOdometerThresholdKm = 500;
  static const int dueSoonDaysThreshold = 14;

  /// Calculates [MaintenanceStatus] from odometer and/or due date.
  ///
  /// - [MaintenanceStatus.overdue] if `currentOdometer >= nextDueOdometer`
  ///   OR `now >= nextDueDate`.
  /// - [MaintenanceStatus.dueSoon] if `(nextDueOdometer - currentOdometer) <= 500`
  ///   OR `nextDueDate.difference(now).inDays <= 14`.
  /// - Otherwise [MaintenanceStatus.ok].
  static MaintenanceStatus calculateStatus({
    required int currentOdometer,
    int? nextDueOdometer,
    DateTime? nextDueDate,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();

    final isOdometerOverdue =
        nextDueOdometer != null && currentOdometer >= nextDueOdometer;
    final isDateOverdue =
        nextDueDate != null && !referenceNow.isBefore(nextDueDate);

    if (isOdometerOverdue || isDateOverdue) {
      return MaintenanceStatus.overdue;
    }

    final isOdometerDueSoon = nextDueOdometer != null &&
        (nextDueOdometer - currentOdometer) <= dueSoonOdometerThresholdKm;
    final isDateDueSoon = nextDueDate != null &&
        nextDueDate.difference(referenceNow).inDays <= dueSoonDaysThreshold;

    if (isOdometerDueSoon || isDateDueSoon) {
      return MaintenanceStatus.dueSoon;
    }

    return MaintenanceStatus.ok;
  }

  /// Helper to compute a future date by adding [months] cleanly.
  static DateTime addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + (date.month - 1) + months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay =
        date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(
      targetYear,
      targetMonth,
      clampedDay,
      date.hour,
      date.minute,
      date.second,
    );
  }
}
