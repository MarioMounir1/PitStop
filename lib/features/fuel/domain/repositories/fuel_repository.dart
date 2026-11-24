import 'package:pitstop/core/database/app_database.dart';

/// Domain contract for vehicle fuel fill-up logs.
abstract class FuelRepository {
  Stream<List<FuelLog>> watchFuelLogs(String vehicleId);
  Future<List<FuelLog>> getFuelLogs(String vehicleId);
  Future<void> addFuelLog(FuelLogsCompanion log);
  Future<void> updateFuelLog(FuelLogsCompanion log);
  Future<void> deleteFuelLog(String id);
}
