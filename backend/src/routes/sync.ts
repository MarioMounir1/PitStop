import { Router } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
import { syncPushPayloadSchema } from '../schemas/models';
import { PitStopDataStore } from '../services/pitstopStore';

/**
 * Offline-first sync endpoints matching PitStop's `BackupService` JSON contract:
 * - `POST /api/sync/push` — uploads local Drift tables to Firestore.
 * - `GET  /api/sync/pull` — downloads full user snapshot for Drift restore.
 */
export function createSyncRouter(store: PitStopDataStore): Router {
  const router = Router();

  router.post('/push', async (req: AuthenticatedRequest, res, next) => {
    try {
      const parsed = syncPushPayloadSchema.parse(req.body);
      const summary = await store.pushAll(req.uid!, parsed.tables);
      res.json({
        status: 'synced',
        syncedAt: new Date().toISOString(),
        summary,
      });
    } catch (err) {
      next(err);
    }
  });

  router.get('/pull', async (req: AuthenticatedRequest, res, next) => {
    try {
      const tables = await store.pullAll(req.uid!);
      res.json({
        app: 'pitstop',
        formatVersion: 1,
        schemaVersion: 1,
        exportedAt: new Date().toISOString(),
        tables,
      });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
