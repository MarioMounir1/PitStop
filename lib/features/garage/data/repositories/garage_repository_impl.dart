import 'package:drift/drift.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/features/garage/domain/repositories/garage_repository.dart';

/// Drift-backed implementation of [GarageRepository].
class GarageRepositoryImpl implements GarageRepository {
  GarageRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Vehicle>> watchVehicles() {
    return (_db.select(_db.vehicles)
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .watch();
  }

  @override
  Stream<Vehicle?> watchActiveVehicle() {
    return (_db.select(_db.vehicles)
          ..where((v) => v.isActive.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  @override
  Future<List<Vehicle>> getVehicles() {
    return (_db.select(_db.vehicles)
          ..orderBy([(v) => OrderingTerm.desc(v.createdAt)]))
        .get();
  }

  @override
  Future<Vehicle?> getVehicleById(String id) {
    return (_db.select(_db.vehicles)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<void> addVehicle(VehiclesCompanion vehicle) async {
    await _db.transaction(() async {
      final existing = await _db.select(_db.vehicles).get();
      final shouldBeActive = existing.isEmpty ||
          (vehicle.isActive.present && vehicle.isActive.value);

      if (shouldBeActive && existing.isNotEmpty) {
        await _db
            .update(_db.vehicles)
            .write(const VehiclesCompanion(isActive: Value(false)));
      }

      await _db.into(_db.vehicles).insert(
            vehicle.copyWith(isActive: Value(shouldBeActive)),
          );
    });
  }

  @override
  Future<void> updateVehicle(VehiclesCompanion vehicle) async {
    if (!vehicle.id.present) {
      throw ArgumentError('Vehicle id is required for update.');
    }
    await (_db.update(_db.vehicles)
          ..where((v) => v.id.equals(vehicle.id.value)))
        .write(vehicle);
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await _db.transaction(() async {
      final target = await getVehicleById(id);
      await (_db.delete(_db.vehicles)..where((v) => v.id.equals(id))).go();

      if (target?.isActive == true) {
        final remaining = await getVehicles();
        if (remaining.isNotEmpty) {
          await setActiveVehicle(remaining.first.id);
        }
      }
    });
  }

  @override
  Future<void> setActiveVehicle(String id) async {
    await _db.transaction(() async {
      await _db
          .update(_db.vehicles)
          .write(const VehiclesCompanion(isActive: Value(false)));
      await (_db.update(_db.vehicles)..where((v) => v.id.equals(id)))
          .write(const VehiclesCompanion(isActive: Value(true)));
    });
  }

  @override
  Future<void> updateOdometerIfHigher(String vehicleId, int newOdometer) async {
    final vehicle = await getVehicleById(vehicleId);
    if (vehicle == null || newOdometer <= vehicle.currentOdometer) return;

    await (_db.update(_db.vehicles)..where((v) => v.id.equals(vehicleId)))
        .write(VehiclesCompanion(currentOdometer: Value(newOdometer)));
  }
}
