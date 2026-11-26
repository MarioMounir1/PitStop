import { NextFunction, Response, Router } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth';
import { NotificationQueue } from '../queues/notificationQueue';
import { PushService } from '../services/pushService';

const registerDeviceSchema = z.object({
  token: z.string().min(10, 'FCM device token is required'),
  platform: z
    .enum(['android', 'ios', 'web', 'macos', 'unknown'])
    .default('unknown'),
});

const sendPushSchema = z.object({
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(500),
  data: z.record(z.string(), z.string()).optional(),
  delayMs: z.number().int().min(0).max(30 * 24 * 60 * 60 * 1000).optional(),
});

const scheduleReminderSchema = z.object({
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(500),
  scheduledAt: z.string().datetime({ message: 'scheduledAt must be an ISO-8601 timestamp' }),
  vehicleId: z.string().optional(),
  reminderType: z.string().optional(),
  data: z.record(z.string(), z.string()).optional(),
});

export function createNotificationsRouter(
  pushService: PushService,
  notificationQueue: NotificationQueue,
): Router {
  const router = Router();

  // Register or refresh a device's FCM push token
  router.post(
    '/devices',
    async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      try {
        const uid = req.uid!;
        const parsed = registerDeviceSchema.parse(req.body);
        await pushService.registerDevice(uid, parsed.token, parsed.platform);
        res.status(201).json({ status: 'registered', platform: parsed.platform });
      } catch (err) {
        next(err);
      }
    },
  );

  // Unregister a device's FCM push token
  router.delete(
    '/devices/:token',
    async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      try {
        const uid = req.uid!;
        const token = decodeURIComponent(String(req.params.token ?? ''));
        if (!token) {
          res.status(400).json({ error: 'Device token is required' });
          return;
        }
        await pushService.unregisterDevice(uid, token);
        res.status(200).json({ status: 'unregistered' });
      } catch (err) {
        next(err);
      }
    },
  );

  // Enqueue an immediate or delayed push notification via BullMQ
  router.post(
    '/send',
    async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      try {
        const uid = req.uid!;
        const parsed = sendPushSchema.parse(req.body);
        const result = await notificationQueue.enqueuePush(
          {
            uid,
            payload: {
              title: parsed.title,
              body: parsed.body,
              data: parsed.data,
            },
          },
          { delayMs: parsed.delayMs },
        );
        res.status(202).json(result);
      } catch (err) {
        next(err);
      }
    },
  );

  // Schedule a maintenance/license/insurance push reminder at an ISO timestamp
  router.post(
    '/schedule-reminder',
    async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      try {
        const uid = req.uid!;
        const parsed = scheduleReminderSchema.parse(req.body);
        const result = await notificationQueue.enqueueReminder(
          {
            uid,
            vehicleId: parsed.vehicleId,
            reminderType: parsed.reminderType,
            payload: {
              title: parsed.title,
              body: parsed.body,
              data: {
                ...(parsed.data ?? {}),
                ...(parsed.vehicleId ? { vehicleId: parsed.vehicleId } : {}),
                ...(parsed.reminderType
                  ? { reminderType: parsed.reminderType }
                  : {}),
              },
            },
          },
          new Date(parsed.scheduledAt),
        );
        res.status(202).json(result);
      } catch (err) {
        next(err);
      }
    },
  );

  // Inspect BullMQ queue counts
  router.get(
    '/queue-status',
    async (_req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      try {
        const status = await notificationQueue.getStatus();
        res.json(status);
      } catch (err) {
        next(err);
      }
    },
  );

  return router;
}
