import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torq/core/database/app_database.dart';
import 'package:torq/core/services/backup_service.dart';
import 'package:torq/features/expenses/data/repositories/expenses_repository_impl.dart';
import 'package:torq/features/fuel/data/repositories/fuel_repository_impl.dart';
import 'package:torq/features/garage/data/repositories/garage_repository_impl.dart';
import 'package:torq/features/maintenance/data/repositories/maintenance_repository_impl.dart';

void main() {
  late AppDatabase db;
  late GarageRepositoryImpl garageRepo;
  late MaintenanceRepositoryImpl maintenanceRepo;
  late FuelRepositoryImpl fuelRepo;
  late ExpensesRepositoryImpl expensesRepo;
  late BackupService backupService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    garageRepo = GarageRepositoryImpl(db);
    maintenanceRepo = MaintenanceRepositoryImpl(db);
    fuelRepo = FuelRepositoryImpl(db);
    expensesRepo = ExpensesRepositoryImpl(db);
    backupService = BackupService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('adding first vehicle sets it active and odometer syncs on service/fuel', () async {
    await garageRepo.addVehicle(
      VehiclesCompanion.insert(
        id: 'v1',
        make: 'Toyota',
        model: 'Corolla',
        year: 2022,
        currentOdometer: const Value(50000),
      ),
    );

    final active = await garageRepo.watchActiveVehicle().first;
    expect(active?.id, 'v1');
    expect(active?.currentOdometer, 50000);

    await maintenanceRepo.addRecord(
      MaintenanceRecordsCompanion.insert(
        id: 'm1',
        vehicleId: 'v1',
        category: 'engine_oil',
        title: 'Engine Oil',
        serviceDate: DateTime(2026, 4, 1),
        odometerAtService: 52500,
        cost: 1800,
        nextDueOdometer: const Value(62500),
      ),
    );

    final afterService = await garageRepo.getVehicleById('v1');
    expect(afterService?.currentOdometer, 52500);

    await fuelRepo.addFuelLog(
      FuelLogsCompanion.insert(
        id: 'f1',
        vehicleId: 'v1',
        date: DateTime(2026, 4, 5),
        odometer: 53000,
        liters: 40,
        pricePerLiter: 15,
        totalCost: 600,
      ),
    );

    final afterFuel = await garageRepo.getVehicleById('v1');
    expect(afterFuel?.currentOdometer, 53000);
  });

  test('BackupService exports and restores all 4 tables atomically', () async {
    await garageRepo.addVehicle(
      VehiclesCompanion.insert(
        id: 'v1',
        make: 'Honda',
        model: 'Civic',
        year: 2023,
        currentOdometer: const Value(30000),
      ),
    );
    await maintenanceRepo.addRecord(
      MaintenanceRecordsCompanion.insert(
        id: 'm1',
        vehicleId: 'v1',
        category: 'oil_filter',
        title: 'Oil Filter',
        serviceDate: DateTime(2026, 3, 1),
        odometerAtService: 30000,
        cost: 450,
      ),
    );
    await fuelRepo.addFuelLog(
      FuelLogsCompanion.insert(
        id: 'f1',
        vehicleId: 'v1',
        date: DateTime(2026, 3, 10),
        odometer: 30400,
        liters: 35,
        pricePerLiter: 15,
        totalCost: 525,
      ),
    );
    await expensesRepo.addExpense(
      ExpensesCompanion.insert(
        id: 'e1',
        vehicleId: 'v1',
        category: 'wash',
        title: 'Full Wash',
        date: DateTime(2026, 3, 12),
        amount: 200,
      ),
    );

    final exportedJson = await backupService.exportToJsonString();

    // Wipe database via cascade delete
    await garageRepo.deleteVehicle('v1');
    expect(await garageRepo.getVehicles(), isEmpty);

    // Restore from JSON
    final summary = await backupService.restoreFromJsonString(exportedJson);
    expect(summary.vehiclesCount, 1);
    expect(summary.maintenanceCount, 1);
    expect(summary.fuelLogsCount, 1);
    expect(summary.expensesCount, 1);

    final restoredVehicles = await garageRepo.getVehicles();
    expect(restoredVehicles.single.make, 'Honda');
  });
}
