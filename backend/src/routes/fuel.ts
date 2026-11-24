import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { HttpError } from '../middleware/errorHandler';
import { fuelLogSchema, fuelLogUpdateSchema } from '../schemas/models';
import { TorqDataStore } from '../services/torqStore';

export function createFuelRouter(store: TorqDataStore): Router {
  const router = Router();

  router.get('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const vehicleId =
        typeof req.query.vehicleId === 'string'
          ? req.query.vehicleId
          : undefined;
      const logs = await store.listFuelLogs(req.uid!, vehicleId);
      res.json({ data: logs });
    } catch (err) {
      next(err);
    }
  });

  router.post('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const payload = fuelLogSchema.parse(req.body);
      const saved = await store.upsertFuelLog(req.uid!, payload);
      res.status(201).json({ data: saved });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const patch = fuelLogUpdateSchema.parse(req.body);
      const updated = await store.updateFuelLog(
        req.uid!,
        String(req.params.id),
        patch,
      );
      if (!updated) {
        throw new HttpError(404, 'Fuel log not found.');
      }
      res.json({ data: updated });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const deleted = await store.deleteFuelLog(
        req.uid!,
        String(req.params.id),
      );
      if (!deleted) {
        throw new HttpError(404, 'Fuel log not found.');
      }
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
