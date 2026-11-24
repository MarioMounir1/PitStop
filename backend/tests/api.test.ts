import assert from 'node:assert/strict';
import { AddressInfo } from 'node:net';
import test from 'node:test';
import { createApp } from '../src/app';
import {
  ExpenseDto,
  FuelLogDto,
  MaintenanceRecordDto,
  SyncTablesPayload,
  VehicleDto,
} from '../src/schemas/models';
import { TorqDataStore } from '../src/services/torqStore';

class InMemoryTorqStore implements TorqDataStore {
  private readonly vehicles = new Map<string, Map<string, VehicleDto>>();
  private readonly maintenance = new Map<
    string,
    Map<string, MaintenanceRecordDto>
  >();
  private readonly fuel = new Map<string, Map<string, FuelLogDto>>();
  private readonly expenses = new Map<string, Map<string, ExpenseDto>>();

  private bucket<T>(root: Map<string, Map<string, T>>, uid: string) {
    let m = root.get(uid);
    if (!m) {
      m = new Map<string, T>();
      root.set(uid, m);
    }
    return m;
  }

  async listVehicles(uid: string) {
    return [...this.bucket(this.vehicles, uid).values()];
  }
  async upsertVehicle(uid: string, v: VehicleDto) {
    this.bucket(this.vehicles, uid).set(v.id, v);
    return v;
  }
  async updateVehicle(uid: string, id: string, patch: Partial<VehicleDto>) {
    const existing = this.bucket(this.vehicles, uid).get(id);
    if (!existing) return null;
    const updated = { ...existing, ...patch };
    this.bucket(this.vehicles, uid).set(id, updated);
    return updated;
  }
  async deleteVehicleCascade(uid: string, id: string) {
    const b = this.bucket(this.vehicles, uid);
    if (!b.has(id)) return false;
    b.delete(id);
    for (const [k, r] of this.bucket(this.maintenance, uid)) {
      if (r.vehicleId === id) this.bucket(this.maintenance, uid).delete(k);
    }
    for (const [k, f] of this.bucket(this.fuel, uid)) {
      if (f.vehicleId === id) this.bucket(this.fuel, uid).delete(k);
    }
    for (const [k, e] of this.bucket(this.expenses, uid)) {
      if (e.vehicleId === id) this.bucket(this.expenses, uid).delete(k);
    }
    return true;
  }

  async listMaintenance(uid: string, vehicleId?: string) {
    const all = [...this.bucket(this.maintenance, uid).values()];
    return vehicleId ? all.filter((r) => r.vehicleId === vehicleId) : all;
  }
  async upsertMaintenance(uid: string, r: MaintenanceRecordDto) {
    this.bucket(this.maintenance, uid).set(r.id, r);
    return r;
  }
  async updateMaintenance(
    uid: string,
    id: string,
    patch: Partial<MaintenanceRecordDto>,
  ) {
    const existing = this.bucket(this.maintenance, uid).get(id);
    if (!existing) return null;
    const updated = { ...existing, ...patch };
    this.bucket(this.maintenance, uid).set(id, updated);
    return updated;
  }
  async deleteMaintenance(uid: string, id: string) {
    return this.bucket(this.maintenance, uid).delete(id);
  }

  async listFuelLogs(uid: string, vehicleId?: string) {
    const all = [...this.bucket(this.fuel, uid).values()];
    return vehicleId ? all.filter((f) => f.vehicleId === vehicleId) : all;
  }
  async upsertFuelLog(uid: string, f: FuelLogDto) {
    this.bucket(this.fuel, uid).set(f.id, f);
    return f;
  }
  async updateFuelLog(uid: string, id: string, patch: Partial<FuelLogDto>) {
    const existing = this.bucket(this.fuel, uid).get(id);
    if (!existing) return null;
    const updated = { ...existing, ...patch };
    this.bucket(this.fuel, uid).set(id, updated);
    return updated;
  }
  async deleteFuelLog(uid: string, id: string) {
    return this.bucket(this.fuel, uid).delete(id);
  }

  async listExpenses(uid: string, vehicleId?: string) {
    const all = [...this.bucket(this.expenses, uid).values()];
    return vehicleId ? all.filter((e) => e.vehicleId === vehicleId) : all;
  }
  async upsertExpense(uid: string, e: ExpenseDto) {
    this.bucket(this.expenses, uid).set(e.id, e);
    return e;
  }
  async updateExpense(uid: string, id: string, patch: Partial<ExpenseDto>) {
    const existing = this.bucket(this.expenses, uid).get(id);
    if (!existing) return null;
    const updated = { ...existing, ...patch };
    this.bucket(this.expenses, uid).set(id, updated);
    return updated;
  }
  async deleteExpense(uid: string, id: string) {
    return this.bucket(this.expenses, uid).delete(id);
  }

  async pushAll(uid: string, tables: SyncTablesPayload) {
    for (const v of tables.vehicles) await this.upsertVehicle(uid, v);
    for (const r of tables.maintenanceRecords)
      await this.upsertMaintenance(uid, r);
    for (const f of tables.fuelLogs) await this.upsertFuelLog(uid, f);
    for (const e of tables.expenses) await this.upsertExpense(uid, e);
    return {
      vehiclesCount: tables.vehicles.length,
      maintenanceCount: tables.maintenanceRecords.length,
      fuelLogsCount: tables.fuelLogs.length,
      expensesCount: tables.expenses.length,
    };
  }

  async pullAll(uid: string): Promise<SyncTablesPayload> {
    return {
      vehicles: await this.listVehicles(uid),
      maintenanceRecords: await this.listMaintenance(uid),
      fuelLogs: await this.listFuelLogs(uid),
      expenses: await this.listExpenses(uid),
    };
  }
}

test('Torq Node.js + Firebase API routes (auth, CRUD, cascade delete, sync)', async () => {
  const store = new InMemoryTorqStore();
  const app = createApp({
    store,
    enableLogging: false,
    tokenVerifier: async (token) => {
      if (token === 'valid-firebase-token') return { uid: 'user-123' };
      throw new Error('Invalid token');
    },
  });

  const server = app.listen(0);
  const { port } = server.address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}`;
  const authHeaders = {
    Authorization: 'Bearer valid-firebase-token',
    'Content-Type': 'application/json',
  };

  try {
    // 1. Health endpoint is public
    const healthRes = await fetch(`${baseUrl}/api/health`);
    assert.equal(healthRes.status, 200);
    const healthBody = (await healthRes.json()) as { status: string };
    assert.equal(healthBody.status, 'ok');

    // 2. Protected route rejects missing token
    const unauthRes = await fetch(`${baseUrl}/api/vehicles`);
    assert.equal(unauthRes.status, 401);

    // 3. Push full offline-first sync payload
    const pushRes = await fetch(`${baseUrl}/api/sync/push`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({
        app: 'torq',
        formatVersion: 1,
        tables: {
          vehicles: [
            {
              id: 'v1',
              make: 'Toyota',
              model: 'Corolla',
              year: 2022,
              currentOdometer: 50000,
              distanceUnit: 'km',
              currencyCode: 'EGP',
              fuelType: 'petrol_92',
              isActive: true,
            },
          ],
          maintenanceRecords: [
            {
              id: 'm1',
              vehicleId: 'v1',
              category: 'engine_oil',
              title: 'Engine Oil',
              serviceDate: '2026-04-01T00:00:00.000Z',
              odometerAtService: 50000,
              cost: 1800,
            },
          ],
          fuelLogs: [
            {
              id: 'f1',
              vehicleId: 'v1',
              date: '2026-04-05T00:00:00.000Z',
              odometer: 50500,
              liters: 40,
              pricePerLiter: 15,
              totalCost: 600,
              isFullTank: true,
            },
          ],
          expenses: [
            {
              id: 'e1',
              vehicleId: 'v1',
              category: 'wash',
              title: 'Full Wash',
              date: '2026-04-06T00:00:00.000Z',
              amount: 200,
            },
          ],
        },
      }),
    });
    assert.equal(pushRes.status, 200);

    // 4. Pull snapshot returns all 4 tables
    const pullRes = await fetch(`${baseUrl}/api/sync/pull`, {
      headers: authHeaders,
    });
    assert.equal(pullRes.status, 200);
    const pullBody = (await pullRes.json()) as { tables: SyncTablesPayload };
    assert.equal(pullBody.tables.vehicles.length, 1);
    assert.equal(pullBody.tables.maintenanceRecords.length, 1);
    assert.equal(pullBody.tables.fuelLogs.length, 1);
    assert.equal(pullBody.tables.expenses.length, 1);

    // 5. Cascade delete vehicle removes child records
    const delRes = await fetch(`${baseUrl}/api/vehicles/v1`, {
      method: 'DELETE',
      headers: authHeaders,
    });
    assert.equal(delRes.status, 204);

    const afterDelete = await fetch(`${baseUrl}/api/sync/pull`, {
      headers: authHeaders,
    });
    const afterBody = (await afterDelete.json()) as {
      tables: SyncTablesPayload;
    };
    assert.equal(afterBody.tables.vehicles.length, 0);
    assert.equal(afterBody.tables.maintenanceRecords.length, 0);
    assert.equal(afterBody.tables.fuelLogs.length, 0);
    assert.equal(afterBody.tables.expenses.length, 0);
  } finally {
    server.close();
  }
});
