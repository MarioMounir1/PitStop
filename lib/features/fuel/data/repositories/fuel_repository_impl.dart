import 'package:drift/drift.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/utils/fuel_calculator.dart';
import 'package:torq/features/fuel/domain/repositories/fuel_repository.dart';

/// Drift-backed implementation of [FuelRepository] that recalculates
/// `consumptionKmPerL` on every mutation and keeps `vehicle.currentOdometer` synced.
class FuelRepositoryImpl implements FuelRepository {
  FuelRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<FuelLog>> watchFuelLogs(String vehicleId) {
    return (_db.select(_db.fuelLogs)
          ..where((f) => f.vehicleId.equals(vehicleId))
          ..orderBy([
            (f) => OrderingTerm.desc(f.date),
            (f) => OrderingTerm.desc(f.odometer),
          ]))
        .watch();
  }

  @override
  Future<List<FuelLog>> getFuelLogs(String vehicleId) {
    return (_db.select(_db.fuelLogs)
          ..where((f) => f.vehicleId.equals(vehicleId))
          ..orderBy([
            (f) => OrderingTerm.desc(f.date),
            (f) => OrderingTerm.desc(f.odometer),
          ]))
        .get();
  }

  @override
  Future<void> addFuelLog(FuelLogsCompanion log) async {
    await _db.transaction(() async {
      await _db.into(_db.fuelLogs).insert(log);
      if (log.vehicleId.present) {
        await _recalculateConsumption(log.vehicleId.value);
        if (log.odometer.present) {
          await _syncOdometerIfHigher(log.vehicleId.value, log.odometer.value);
        }
      }
    });
  }

  @override
  Future<void> updateFuelLog(FuelLogsCompanion log) async {
    if (!log.id.present) {
      throw ArgumentError('FuelLog id is required for update.');
    }
    await _db.transaction(() async {
      final existing = await (_db.select(_db.fuelLogs)
            ..where((f) => f.id.equals(log.id.value)))
          .getSingleOrNull();
      await (_db.update(_db.fuelLogs)..where((f) => f.id.equals(log.id.value)))
          .write(log);
      final vehicleId =
          log.vehicleId.present ? log.vehicleId.value : existing?.vehicleId;
      if (vehicleId != null) {
        await _recalculateConsumption(vehicleId);
        if (log.odometer.present) {
          await _syncOdometerIfHigher(vehicleId, log.odometer.value);
        }
      }
    });
  }

  @override
  Future<void> deleteFuelLog(String id) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.fuelLogs)
            ..where((f) => f.id.equals(id)))
          .getSingleOrNull();
      await (_db.delete(_db.fuelLogs)..where((f) => f.id.equals(id))).go();
      if (existing != null) {
        await _recalculateConsumption(existing.vehicleId);
      }
    });
  }

  Future<void> _recalculateConsumption(String vehicleId) async {
    final logs = await getFuelLogs(vehicleId);
    final calculated = FuelCalculator.calculateConsumptionMap(logs);

    await _db.batch((batch) {
      for (final log in logs) {
        final nextVal = calculated[log.id];
        if (log.consumptionKmPerL != nextVal) {
          batch.update(
            _db.fuelLogs,
            FuelLogsCompanion(consumptionKmPerL: Value(nextVal)),
            where: (f) => f.id.equals(log.id),
          );
        }
      }
    });
  }

  Future<void> _syncOdometerIfHigher(String vehicleId, int odometer) async {
    final vehicle = await (_db.select(_db.vehicles)
          ..where((v) => v.id.equals(vehicleId)))
        .getSingleOrNull();
    if (vehicle != null && odometer > vehicle.currentOdometer) {
      await (_db.update(_db.vehicles)..where((v) => v.id.equals(vehicleId)))
          .write(VehiclesCompanion(currentOdometer: Value(odometer)));
    }
  }
}
