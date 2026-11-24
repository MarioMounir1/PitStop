import 'package:drift/drift.dart';
import 'package:pitstop/core/database/tables/vehicles_table.dart';

class MaintenanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text().references(
        Vehicles,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get category => text()();
  TextColumn get title => text()();
  DateTimeColumn get serviceDate => dateTime()();
  IntColumn get odometerAtService => integer()();
  RealColumn get cost => real()();
  TextColumn get serviceCenter => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  IntColumn get nextDueOdometer => integer().nullable()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
