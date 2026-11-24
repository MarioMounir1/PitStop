import 'package:pitstop/core/database/app_database.dart';

/// Domain contract for vehicle maintenance records.
abstract class MaintenanceRepository {
  Stream<List<MaintenanceRecord>> watchRecords(String vehicleId);
  Future<List<MaintenanceRecord>> getRecords(String vehicleId);
  Future<void> addRecord(MaintenanceRecordsCompanion record);
  Future<void> updateRecord(MaintenanceRecordsCompanion record);
  Future<void> deleteRecord(String id);
}
