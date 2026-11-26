import cors from 'cors';
import express, { Express } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { createAuthMiddleware, TokenVerifier } from './middleware/auth';
import { errorHandler } from './middleware/errorHandler';
import { createCarViewsRouter } from './routes/carViews';
import { createExpensesRouter } from './routes/expenses';
import { createFuelRouter } from './routes/fuel';
import { createHealthRouter } from './routes/health';
import { createMaintenanceRouter } from './routes/maintenance';
import { createNotificationsRouter } from './routes/notifications';
import { createSyncRouter } from './routes/sync';
import { createVehiclesRouter } from './routes/vehicles';
import { getRedisUrl } from './config/redis';
import {
  BullMqNotificationQueue,
  NotificationQueue,
} from './queues/notificationQueue';
import {
  CarViewRenderer,
  GeminiCarViewRenderer,
} from './services/carRenderService';
import { FirestorePitStopStore, PitStopDataStore } from './services/pitstopStore';
import { FirebasePushService, PushService } from './services/pushService';

export interface CreateAppOptions {
  store?: PitStopDataStore;
  tokenVerifier?: TokenVerifier;
  carViewRenderer?: CarViewRenderer;
  pushService?: PushService;
  notificationQueue?: NotificationQueue;
  enableLogging?: boolean;
}

export function createApp(options: CreateAppOptions = {}): Express {
  const app = express();
  const store = options.store ?? new FirestorePitStopStore();
  const carViewRenderer = options.carViewRenderer ?? new GeminiCarViewRenderer();
  const pushService = options.pushService ?? new FirebasePushService();
  const notificationQueue =
    options.notificationQueue ??
    new BullMqNotificationQueue(pushService, getRedisUrl());
  const requireAuth = createAuthMiddleware(options.tokenVerifier);

  app.use(helmet());
  app.use(
    cors({
      origin: process.env.CORS_ORIGIN || '*',
    }),
  );
  app.use(express.json({ limit: '10mb' }));
  if (options.enableLogging !== false && process.env.NODE_ENV !== 'test') {
    app.use(morgan('dev'));
  }

  // Public health endpoint
  app.use('/api/health', createHealthRouter());

  // Protected Firebase-authenticated API routes
  app.use('/api/vehicles', requireAuth, createVehiclesRouter(store));
  app.use('/api/maintenance', requireAuth, createMaintenanceRouter(store));
  app.use('/api/fuel', requireAuth, createFuelRouter(store));
  app.use('/api/expenses', requireAuth, createExpensesRouter(store));
  app.use('/api/sync', requireAuth, createSyncRouter(store));
  app.use('/api/car-views', requireAuth, createCarViewsRouter(carViewRenderer));
  app.use(
    '/api/notifications',
    requireAuth,
    createNotificationsRouter(pushService, notificationQueue),
  );

  app.use(errorHandler);
  return app;
}
