import admin from 'firebase-admin';
import { getFirestoreDb } from '../config/firebase';
import {
  ExpenseDto,
  FuelLogDto,
  MaintenanceRecordDto,
  SyncTablesPayload,
  VehicleDto,
} from '../schemas/models';

export interface TorqDataStore {
  listVehicles(uid: string): Promise<VehicleDto[]>;
  upsertVehicle(uid: string, vehicle: VehicleDto): Promise<VehicleDto>;
  updateVehicle(
    uid: string,
    id: string,
    patch: Partial<VehicleDto>,
  ): Promise<VehicleDto | null>;
  deleteVehicleCascade(uid: string, id: string): Promise<boolean>;

  listMaintenance(uid: string, vehicleId?: string): Promise<MaintenanceRecordDto[]>;
  upsertMaintenance(
    uid: string,
    record: MaintenanceRecordDto,
  ): Promise<MaintenanceRecordDto>;
  updateMaintenance(
    uid: string,
    id: string,
    patch: Partial<MaintenanceRecordDto>,
  ): Promise<MaintenanceRecordDto | null>;
  deleteMaintenance(uid: string, id: string): Promise<boolean>;

  listFuelLogs(uid: string, vehicleId?: string): Promise<FuelLogDto[]>;
  upsertFuelLog(uid: string, log: FuelLogDto): Promise<FuelLogDto>;
  updateFuelLog(
    uid: string,
    id: string,
    patch: Partial<FuelLogDto>,
  ): Promise<FuelLogDto | null>;
  deleteFuelLog(uid: string, id: string): Promise<boolean>;

  listExpenses(uid: string, vehicleId?: string): Promise<ExpenseDto[]>;
  upsertExpense(uid: string, expense: ExpenseDto): Promise<ExpenseDto>;
  updateExpense(
    uid: string,
    id: string,
    patch: Partial<ExpenseDto>,
  ): Promise<ExpenseDto | null>;
  deleteExpense(uid: string, id: string): Promise<boolean>;

  pushAll(uid: string, tables: SyncTablesPayload): Promise<{
    vehiclesCount: number;
    maintenanceCount: number;
    fuelLogsCount: number;
    expensesCount: number;
  }>;
  pullAll(uid: string): Promise<SyncTablesPayload>;
}

/**
 * Firestore-backed implementation storing all user documents under:
 * `users/{uid}/vehicles/{id}`
 * `users/{uid}/maintenanceRecords/{id}`
 * `users/{uid}/fuelLogs/{id}`
 * `users/{uid}/expenses/{id}`
 */
export class FirestoreTorqStore implements TorqDataStore {
  private get db(): admin.firestore.Firestore {
    return getFirestoreDb();
  }

  private userCol(
    uid: string,
    collection: 'vehicles' | 'maintenanceRecords' | 'fuelLogs' | 'expenses',
  ) {
    return this.db.collection('users').doc(uid).collection(collection);
  }

  async listVehicles(uid: string): Promise<VehicleDto[]> {
    const snap = await this.userCol(uid, 'vehicles').get();
    return snap.docs.map((d) => d.data() as VehicleDto);
  }

  async upsertVehicle(uid: string, vehicle: VehicleDto): Promise<VehicleDto> {
    const doc: VehicleDto = {
      ...vehicle,
      createdAt: vehicle.createdAt ?? new Date().toISOString(),
    };
    await this.userCol(uid, 'vehicles').doc(doc.id).set(doc, { merge: true });
    return doc;
  }

  async updateVehicle(
    uid: string,
    id: string,
    patch: Partial<VehicleDto>,
  ): Promise<VehicleDto | null> {
    const ref = this.userCol(uid, 'vehicles').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return null;
    await ref.set(patch, { merge: true });
    const updated = await ref.get();
    return updated.data() as VehicleDto;
  }

  async deleteVehicleCascade(uid: string, id: string): Promise<boolean> {
    const vehicleRef = this.userCol(uid, 'vehicles').doc(id);
    const vehicleSnap = await vehicleRef.get();
    if (!vehicleSnap.exists) return false;

    const batch = this.db.batch();
    batch.delete(vehicleRef);

    for (const colName of [
      'maintenanceRecords',
      'fuelLogs',
      'expenses',
    ] as const) {
      const children = await this.userCol(uid, colName)
        .where('vehicleId', '==', id)
        .get();
      for (const doc of children.docs) {
        batch.delete(doc.ref);
      }
    }

    await batch.commit();
    return true;
  }

  async listMaintenance(
    uid: string,
    vehicleId?: string,
  ): Promise<MaintenanceRecordDto[]> {
    const col = this.userCol(uid, 'maintenanceRecords');
    const snap = vehicleId
      ? await col.where('vehicleId', '==', vehicleId).get()
      : await col.get();
    return snap.docs.map((d) => d.data() as MaintenanceRecordDto);
  }

  async upsertMaintenance(
    uid: string,
    record: MaintenanceRecordDto,
  ): Promise<MaintenanceRecordDto> {
    const doc: MaintenanceRecordDto = {
      ...record,
      createdAt: record.createdAt ?? new Date().toISOString(),
    };
    await this.userCol(uid, 'maintenanceRecords')
      .doc(doc.id)
      .set(doc, { merge: true });
    return doc;
  }

  async updateMaintenance(
    uid: string,
    id: string,
    patch: Partial<MaintenanceRecordDto>,
  ): Promise<MaintenanceRecordDto | null> {
    const ref = this.userCol(uid, 'maintenanceRecords').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return null;
    await ref.set(patch, { merge: true });
    const updated = await ref.get();
    return updated.data() as MaintenanceRecordDto;
  }

  async deleteMaintenance(uid: string, id: string): Promise<boolean> {
    const ref = this.userCol(uid, 'maintenanceRecords').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
  }

  async listFuelLogs(uid: string, vehicleId?: string): Promise<FuelLogDto[]> {
    const col = this.userCol(uid, 'fuelLogs');
    const snap = vehicleId
      ? await col.where('vehicleId', '==', vehicleId).get()
      : await col.get();
    return snap.docs.map((d) => d.data() as FuelLogDto);
  }

  async upsertFuelLog(uid: string, log: FuelLogDto): Promise<FuelLogDto> {
    const doc: FuelLogDto = {
      ...log,
      createdAt: log.createdAt ?? new Date().toISOString(),
    };
    await this.userCol(uid, 'fuelLogs').doc(doc.id).set(doc, { merge: true });
    return doc;
  }

  async updateFuelLog(
    uid: string,
    id: string,
    patch: Partial<FuelLogDto>,
  ): Promise<FuelLogDto | null> {
    const ref = this.userCol(uid, 'fuelLogs').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return null;
    await ref.set(patch, { merge: true });
    const updated = await ref.get();
    return updated.data() as FuelLogDto;
  }

  async deleteFuelLog(uid: string, id: string): Promise<boolean> {
    const ref = this.userCol(uid, 'fuelLogs').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
  }

  async listExpenses(uid: string, vehicleId?: string): Promise<ExpenseDto[]> {
    const col = this.userCol(uid, 'expenses');
    const snap = vehicleId
      ? await col.where('vehicleId', '==', vehicleId).get()
      : await col.get();
    return snap.docs.map((d) => d.data() as ExpenseDto);
  }

  async upsertExpense(uid: string, expense: ExpenseDto): Promise<ExpenseDto> {
    const doc: ExpenseDto = {
      ...expense,
      createdAt: expense.createdAt ?? new Date().toISOString(),
    };
    await this.userCol(uid, 'expenses').doc(doc.id).set(doc, { merge: true });
    return doc;
  }

  async updateExpense(
    uid: string,
    id: string,
    patch: Partial<ExpenseDto>,
  ): Promise<ExpenseDto | null> {
    const ref = this.userCol(uid, 'expenses').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return null;
    await ref.set(patch, { merge: true });
    const updated = await ref.get();
    return updated.data() as ExpenseDto;
  }

  async deleteExpense(uid: string, id: string): Promise<boolean> {
    const ref = this.userCol(uid, 'expenses').doc(id);
    const snap = await ref.get();
    if (!snap.exists) return false;
    await ref.delete();
    return true;
  }

  async pushAll(uid: string, tables: SyncTablesPayload) {
    const operations: Array<(batch: admin.firestore.WriteBatch) => void> = [];

    for (const v of tables.vehicles) {
      operations.push((b) =>
        b.set(this.userCol(uid, 'vehicles').doc(v.id), v, { merge: true }),
      );
    }
    for (const r of tables.maintenanceRecords) {
      operations.push((b) =>
        b.set(this.userCol(uid, 'maintenanceRecords').doc(r.id), r, {
          merge: true,
        }),
      );
    }
    for (const f of tables.fuelLogs) {
      operations.push((b) =>
        b.set(this.userCol(uid, 'fuelLogs').doc(f.id), f, { merge: true }),
      );
    }
    for (const e of tables.expenses) {
      operations.push((b) =>
        b.set(this.userCol(uid, 'expenses').doc(e.id), e, { merge: true }),
      );
    }

    // Firestore limits write batches to 500 ops; chunk safely at 400.
    const chunkSize = 400;
    for (let i = 0; i < operations.length; i += chunkSize) {
      const batch = this.db.batch();
      for (const op of operations.slice(i, i + chunkSize)) {
        op(batch);
      }
      await batch.commit();
    }

    return {
      vehiclesCount: tables.vehicles.length,
      maintenanceCount: tables.maintenanceRecords.length,
      fuelLogsCount: tables.fuelLogs.length,
      expensesCount: tables.expenses.length,
    };
  }

  async pullAll(uid: string): Promise<SyncTablesPayload> {
    const [vehicles, maintenanceRecords, fuelLogs, expenses] =
      await Promise.all([
        this.listVehicles(uid),
        this.listMaintenance(uid),
        this.listFuelLogs(uid),
        this.listExpenses(uid),
      ]);

    return { vehicles, maintenanceRecords, fuelLogs, expenses };
  }
}
