import { z } from 'zod';

const isoDateString = z.string().min(1);
const nullableIsoDateString = z.string().nullable().optional();

export const vehicleSchema = z.object({
  id: z.string().min(1),
  make: z.string().min(1),
  model: z.string().min(1),
  year: z.number().int().min(1950).max(2035),
  plateNumber: z.string().nullable().optional(),
  currentOdometer: z.number().int().min(0).default(0),
  distanceUnit: z.enum(['km', 'mi']).default('km'),
  currencyCode: z.string().min(3).max(5).default('EGP'),
  fuelType: z.string().min(1).default('petrol_92'),
  licenseExpiryDate: nullableIsoDateString,
  insuranceExpiryDate: nullableIsoDateString,
  isActive: z.boolean().default(false),
  createdAt: isoDateString.optional(),
});

export const vehicleUpdateSchema = vehicleSchema.partial().omit({ id: true });

export const maintenanceRecordSchema = z.object({
  id: z.string().min(1),
  vehicleId: z.string().min(1),
  category: z.string().min(1),
  title: z.string().min(1),
  serviceDate: isoDateString,
  odometerAtService: z.number().int().min(0),
  cost: z.number().min(0),
  serviceCenter: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
  receiptImagePath: z.string().nullable().optional(),
  nextDueOdometer: z.number().int().min(0).nullable().optional(),
  nextDueDate: nullableIsoDateString,
  reminderEnabled: z.boolean().default(true),
  isCompleted: z.boolean().default(true),
  createdAt: isoDateString.optional(),
});

export const maintenanceUpdateSchema = maintenanceRecordSchema
  .partial()
  .omit({ id: true });

export const fuelLogSchema = z.object({
  id: z.string().min(1),
  vehicleId: z.string().min(1),
  date: isoDateString,
  odometer: z.number().int().min(0),
  liters: z.number().positive(),
  pricePerLiter: z.number().positive(),
  totalCost: z.number().positive(),
  isFullTank: z.boolean().default(true),
  fuelGrade: z.string().nullable().optional(),
  stationName: z.string().nullable().optional(),
  consumptionKmPerL: z.number().nullable().optional(),
  createdAt: isoDateString.optional(),
});

export const fuelLogUpdateSchema = fuelLogSchema.partial().omit({ id: true });

export const expenseSchema = z.object({
  id: z.string().min(1),
  vehicleId: z.string().min(1),
  category: z.string().min(1),
  title: z.string().min(1),
  date: isoDateString,
  amount: z.number().positive(),
  notes: z.string().nullable().optional(),
  receiptImagePath: z.string().nullable().optional(),
  createdAt: isoDateString.optional(),
});

export const expenseUpdateSchema = expenseSchema.partial().omit({ id: true });

export const syncPushPayloadSchema = z.object({
  app: z.literal('torq').optional(),
  formatVersion: z.number().int().optional(),
  schemaVersion: z.number().int().optional(),
  exportedAt: z.string().optional(),
  tables: z.object({
    vehicles: z.array(vehicleSchema).default([]),
    maintenanceRecords: z.array(maintenanceRecordSchema).default([]),
    fuelLogs: z.array(fuelLogSchema).default([]),
    expenses: z.array(expenseSchema).default([]),
  }),
});

export type VehicleDto = z.infer<typeof vehicleSchema>;
export type MaintenanceRecordDto = z.infer<typeof maintenanceRecordSchema>;
export type FuelLogDto = z.infer<typeof fuelLogSchema>;
export type ExpenseDto = z.infer<typeof expenseSchema>;
export type SyncTablesPayload = z.infer<typeof syncPushPayloadSchema>['tables'];
