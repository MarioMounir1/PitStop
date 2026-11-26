import 'dotenv/config';
import { createApp } from './app';
import { initFirebase } from './config/firebase';
import { getRedisUrl } from './config/redis';
import { BullMqNotificationQueue } from './queues/notificationQueue';
import { FirebasePushService } from './services/pushService';

const port = Number(process.env.PORT ?? 8080);

// Initialize Firebase Admin eagerly if credentials are configured.
if (
  process.env.FIREBASE_PROJECT_ID ||
  process.env.GOOGLE_APPLICATION_CREDENTIALS
) {
  try {
    initFirebase();
    console.log('Firebase Admin SDK initialized.');
  } catch (err) {
    console.warn('Firebase Admin initialization deferred:', err);
  }
} else {
  console.warn(
    'No Firebase credentials found in environment. Set FIREBASE_* or GOOGLE_APPLICATION_CREDENTIALS before calling Firestore routes.',
  );
}

const pushService = new FirebasePushService();
const redisUrl = getRedisUrl();
const notificationQueue = new BullMqNotificationQueue(pushService, redisUrl);

if (redisUrl) {
  notificationQueue.startWorker();
  console.log(`BullMQ notification worker started on Redis (${redisUrl}).`);
} else {
  console.warn(
    'REDIS_URL not set — notifications will use direct FCM delivery without BullMQ queuing.',
  );
}

const app = createApp({ pushService, notificationQueue });

const server = app.listen(port, () => {
  console.log(`PitStop Node.js + Firebase backend listening on http://localhost:${port}`);
});

async function shutdown(signal: string): Promise<void> {
  console.log(`Received ${signal}, shutting down gracefully...`);
  server.close();
  await notificationQueue.close();
  process.exit(0);
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
