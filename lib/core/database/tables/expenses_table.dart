import 'package:drift/drift.dart';
import 'package:torq/core/database/tables/vehicles_table.dart';

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text().references(
        Vehicles,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get category => text()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
