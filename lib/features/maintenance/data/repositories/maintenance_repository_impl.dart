import 'package:drift/drift.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/features/maintenance/domain/repositories/maintenance_repository.dart';

/// Drift-backed implementation of [MaintenanceRepository] that automatically
/// keeps `vehicle.currentOdometer` synced when a higher service odometer is logged.
class MaintenanceRepositoryImpl implements MaintenanceRepository {
  MaintenanceRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<MaintenanceRecord>> watchRecords(String vehicleId) {
    return (_db.select(_db.maintenanceRecords)
          ..where((r) => r.vehicleId.equals(vehicleId))
          ..orderBy([(r) => OrderingTerm.desc(r.serviceDate)]))
        .watch();
  }

  @override
  Future<List<MaintenanceRecord>> getRecords(String vehicleId) {
    return (_db.select(_db.maintenanceRecords)
          ..where((r) => r.vehicleId.equals(vehicleId))
          ..orderBy([(r) => OrderingTerm.desc(r.serviceDate)]))
        .get();
  }

  @override
  Future<void> addRecord(MaintenanceRecordsCompanion record) async {
    await _db.transaction(() async {
      await _db.into(_db.maintenanceRecords).insert(record);
      if (record.vehicleId.present && record.odometerAtService.present) {
        await _syncOdometerIfHigher(
          record.vehicleId.value,
          record.odometerAtService.value,
        );
      }
    });
  }

  @override
  Future<void> updateRecord(MaintenanceRecordsCompanion record) async {
    if (!record.id.present) {
      throw ArgumentError('MaintenanceRecord id is required for update.');
    }
    await _db.transaction(() async {
      await (_db.update(_db.maintenanceRecords)
            ..where((r) => r.id.equals(record.id.value)))
          .write(record);
      if (record.vehicleId.present && record.odometerAtService.present) {
        await _syncOdometerIfHigher(
          record.vehicleId.value,
          record.odometerAtService.value,
        );
      }
    });
  }

  @override
  Future<void> deleteRecord(String id) async {
    await (_db.delete(_db.maintenanceRecords)..where((r) => r.id.equals(id)))
        .go();
  }

  Future<void> _syncOdometerIfHigher(
    String vehicleId,
    int odometerAtService,
  ) async {
    final vehicle = await (_db.select(_db.vehicles)
          ..where((v) => v.id.equals(vehicleId)))
        .getSingleOrNull();
    if (vehicle != null && odometerAtService > vehicle.currentOdometer) {
      await (_db.update(_db.vehicles)..where((v) => v.id.equals(vehicleId)))
          .write(VehiclesCompanion(currentOdometer: Value(odometerAtService)));
    }
  }
}
