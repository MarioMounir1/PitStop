import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { HttpError } from '../middleware/errorHandler';
import { vehicleSchema, vehicleUpdateSchema } from '../schemas/models';
import { PitStopDataStore } from '../services/pitstopStore';

export function createVehiclesRouter(store: PitStopDataStore): Router {
  const router = Router();

  router.get('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const vehicles = await store.listVehicles(req.uid!);
      res.json({ data: vehicles });
    } catch (err) {
      next(err);
    }
  });

  router.post('/', async (req: AuthenticatedRequest, res, next) => {
    try {
      const payload = vehicleSchema.parse(req.body);
      const saved = await store.upsertVehicle(req.uid!, payload);
      res.status(201).json({ data: saved });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const patch = vehicleUpdateSchema.parse(req.body);
      const updated = await store.updateVehicle(
        req.uid!,
        String(req.params.id),
        patch,
      );
      if (!updated) {
        throw new HttpError(404, 'Vehicle not found.');
      }
      res.json({ data: updated });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/:id', async (req: AuthenticatedRequest, res, next) => {
    try {
      const deleted = await store.deleteVehicleCascade(
        req.uid!,
        String(req.params.id),
      );
      if (!deleted) {
        throw new HttpError(404, 'Vehicle not found.');
      }
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
