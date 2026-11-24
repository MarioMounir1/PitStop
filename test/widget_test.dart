import 'package:flutter_test/flutter_test.dart';
import 'package:pitstop/core/database/app_database.dart';
import 'package:pitstop/core/utils/fuel_calculator.dart';
import 'package:pitstop/core/utils/reminder_calculator.dart';

void main() {
  group('ReminderCalculator', () {
    test('returns overdue when odometer reaches or exceeds nextDueOdometer', () {
      expect(
        ReminderCalculator.calculateStatus(
          currentOdometer: 50000,
          nextDueOdometer: 50000,
        ),
        MaintenanceStatus.overdue,
      );
    });

    test('returns dueSoon when within 500 km or 14 days', () {
      final now = DateTime(2026, 5, 1);
      expect(
        ReminderCalculator.calculateStatus(
          currentOdometer: 49600,
          nextDueOdometer: 50000,
          now: now,
        ),
        MaintenanceStatus.dueSoon,
      );
      expect(
        ReminderCalculator.calculateStatus(
          currentOdometer: 10000,
          nextDueDate: DateTime(2026, 5, 10),
          now: now,
        ),
        MaintenanceStatus.dueSoon,
      );
    });

    test('returns ok when comfortably ahead of both odometer and date', () {
      final now = DateTime(2026, 5, 1);
      expect(
        ReminderCalculator.calculateStatus(
          currentOdometer: 40000,
          nextDueOdometer: 50000,
          nextDueDate: DateTime(2026, 10, 1),
          now: now,
        ),
        MaintenanceStatus.ok,
      );
    });
  });

  group('FuelCalculator', () {
    test('accumulates partial fills between consecutive full tanks', () {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 1, 10);
      final t3 = DateTime(2026, 1, 20);

      final logs = [
        FuelLog(
          id: '1',
          vehicleId: 'v1',
          date: t1,
          odometer: 10000,
          liters: 40,
          pricePerLiter: 15,
          totalCost: 600,
          isFullTank: true,
          createdAt: t1,
        ),
        FuelLog(
          id: '2',
          vehicleId: 'v1',
          date: t2,
          odometer: 10200,
          liters: 10,
          pricePerLiter: 15,
          totalCost: 150,
          isFullTank: false,
          createdAt: t2,
        ),
        FuelLog(
          id: '3',
          vehicleId: 'v1',
          date: t3,
          odometer: 10500,
          liters: 40,
          pricePerLiter: 15,
          totalCost: 600,
          isFullTank: true,
          createdAt: t3,
        ),
      ];

      final map = FuelCalculator.calculateConsumptionMap(logs);
      expect(map['1'], isNull);
      expect(map['2'], isNull);
      // (10500 - 10000) / (10 + 40) = 500 / 50 = 10.0 km/L
      expect(map['3'], closeTo(10.0, 0.001));
    });
  });
}
