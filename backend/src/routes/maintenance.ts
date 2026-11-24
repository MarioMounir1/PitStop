import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { HttpError } from '../middleware/errorHandler';
import {
  maintenanceRecordSchema,
  maintenanceUpdateSchema,
} from '../schemas/models';
import { PitStopDataStore } from '../services/pitstopStore';

export function createMaintenanceRouter(store: PitStopDataStore): Router {
  const router = Router();

  router.get('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const vehicleId =
        typeof req.query.vehicleId === 'string'
          ? req.query.vehicleId
          : undefined;
      const records = await store.listMaintenance(req.uid!, vehicleId);
      res.json({ data: records });
    } catch (err) {
      next(err);
    }
  });

  router.post('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const payload = maintenanceRecordSchema.parse(req.body);
      const saved = await store.upsertMaintenance(req.uid!, payload);
      res.status(201).json({ data: saved });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const patch = maintenanceUpdateSchema.parse(req.body);
      const updated = await store.updateMaintenance(
        req.uid!,
        String(req.params.id),
        patch,
      );
      if (!updated) {
        throw new HttpError(404, 'Maintenance record not found.');
      }
      res.json({ data: updated });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const deleted = await store.deleteMaintenance(
        req.uid!,
        String(req.params.id),
      );
      if (!deleted) {
        throw new HttpError(404, 'Maintenance record not found.');
      }
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
