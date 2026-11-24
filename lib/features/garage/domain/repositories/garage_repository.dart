import 'package:torq/core/database/app_database.dart';

/// Domain contract for managing vehicles in the user's garage.
abstract class GarageRepository {
  Stream<List<Vehicle>> watchVehicles();
  Stream<Vehicle?> watchActiveVehicle();
  Future<List<Vehicle>> getVehicles();
  Future<Vehicle?> getVehicleById(String id);
  Future<void> addVehicle(VehiclesCompanion vehicle);
  Future<void> updateVehicle(VehiclesCompanion vehicle);
  Future<void> deleteVehicle(String id);
  Future<void> setActiveVehicle(String id);
  Future<void> updateOdometerIfHigher(String vehicleId, int newOdometer);
}
