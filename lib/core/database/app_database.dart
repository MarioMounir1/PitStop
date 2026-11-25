import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:pitstop/core/database/tables/expenses_table.dart';
import 'package:pitstop/core/database/tables/fuel_logs_table.dart';
import 'package:pitstop/core/database/tables/maintenance_records_table.dart';
import 'package:pitstop/core/database/tables/vehicles_table.dart';

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(vehicles, vehicles.color);
            await migrator.addColumn(vehicles, vehicles.carViewsJson);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pitstop_db');
  }
}
