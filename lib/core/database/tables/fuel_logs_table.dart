import 'package:drift/drift.dart';
import 'package:pitstop/core/database/tables/vehicles_table.dart';

class FuelLogs extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text().references(
        Vehicles,
        #id,
        onDelete: KeyAction.cascade,
      )();
  DateTimeColumn get date => dateTime()();
  IntColumn get odometer => integer()();
  RealColumn get liters => real()();
  RealColumn get pricePerLiter => real()();
  RealColumn get totalCost => real()();
  BoolColumn get isFullTank => boolean().withDefault(const Constant(true))();
  TextColumn get fuelGrade => text().nullable()();
  TextColumn get stationName => text().nullable()();
  RealColumn get consumptionKmPerL => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
