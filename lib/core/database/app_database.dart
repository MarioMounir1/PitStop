import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:torq/core/database/tables/expenses_table.dart';
import 'package:torq/core/database/tables/fuel_logs_table.dart';
import 'package:torq/core/database/tables/maintenance_records_table.dart';
import 'package:torq/core/database/tables/vehicles_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Vehicles,
    MaintenanceRecords,
    FuelLogs,
    Expenses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'torq_db');
  }
}
