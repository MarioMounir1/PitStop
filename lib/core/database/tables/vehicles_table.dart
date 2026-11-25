import 'package:drift/drift.dart';

class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get make => text()();
  TextColumn get model => text()();
  IntColumn get year => integer()();
  TextColumn get color => text().withDefault(const Constant('White'))();
  TextColumn get plateNumber => text().nullable()();
  IntColumn get currentOdometer => integer().withDefault(const Constant(0))();
  TextColumn get distanceUnit => text().withDefault(const Constant('km'))();
  TextColumn get currencyCode => text().withDefault(const Constant('EGP'))();
  TextColumn get fuelType => text().withDefault(const Constant('petrol_92'))();
  DateTimeColumn get licenseExpiryDate => dateTime().nullable()();
  DateTimeColumn get insuranceExpiryDate => dateTime().nullable()();
  TextColumn get carViewsJson => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
