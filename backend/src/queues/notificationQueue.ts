import { Job, Queue, Worker } from 'bullmq';
import IORedis from 'ioredis';
import { createRedisConnection } from '../config/redis';
import { PushPayload, PushSendResult, PushService } from '../services/pushService';

export const NOTIFICATION_QUEUE_NAME = 'pitstop-notifications';

export type NotificationJobName = 'send-push' | 'maintenance-reminder';

export interface NotificationJobData {
  uid: string;
  payload: PushPayload;
  vehicleId?: string;
  reminderType?: string;
}

export interface QueueStatusSnapshot {
  enabled: boolean;
  waiting: number;
  active: number;
  delayed: number;
  completed: number;
  failed: number;
}

export interface NotificationQueue {
  readonly isEnabled: boolean;
  enqueuePush(
    data: NotificationJobData,
    options?: { delayMs?: number; jobId?: string },
  ): Promise<{ jobId: string; queued: boolean; directResult?: PushSendResult }>;
  enqueueReminder(
    data: NotificationJobData,
    scheduledAt: Date,
  ): Promise<{ jobId: string; delayMs: number; queued: boolean }>;
  getStatus(): Promise<QueueStatusSnapshot>;
  startWorker(): void;
  close(): Promise<void>;
}

/**
 * BullMQ-backed notification queue with automatic Redis connection management.
 * When `redisUrl` is not configured, falls back to immediate direct push delivery
 * so the API remains functional even before Redis is provisioned.
 */
export class BullMqNotificationQueue implements NotificationQueue {
  private readonly pushService: PushService;
  private readonly redisUrl?: string;
  private queueConnection?: IORedis;
  private workerConnection?: IORedis;
  private queue?: Queue<NotificationJobData, PushSendResult, NotificationJobName>;
  private worker?: Worker<NotificationJobData, PushSendResult, NotificationJobName>;

  constructor(pushService: PushService, redisUrl?: string) {
    this.pushService = pushService;
    this.redisUrl = redisUrl;

    if (redisUrl) {
      this.queueConnection = createRedisConnection(redisUrl);
      this.queue = new Queue<NotificationJobData, PushSendResult, NotificationJobName>(
        NOTIFICATION_QUEUE_NAME,
        {
          connection: this.queueConnection,
          defaultJobOptions: {
            attempts: 3,
            backoff: {
              type: 'exponential',
              delay: 5000,
            },
            removeOnComplete: 500,
            removeOnFail: 1000,
          },
        },
      );
    }
  }

  get isEnabled(): boolean {
    return Boolean(this.queue);
  }

  startWorker(): void {
    if (!this.redisUrl || this.worker) return;

    this.workerConnection = createRedisConnection(this.redisUrl);
    this.worker = new Worker<NotificationJobData, PushSendResult, NotificationJobName>(
      NOTIFICATION_QUEUE_NAME,
      async (job: Job<NotificationJobData, PushSendResult, NotificationJobName>) => {
        return this.pushService.sendToUser(job.data.uid, job.data.payload);
      },
      {
        connection: this.workerConnection,
        concurrency: 5,
      },
    );

    this.worker.on('completed', (job, result) => {
      console.log(
        `[BullMQ] Job ${job.id} (${job.name}) completed: sent=${result.sent} failed=${result.failed}`,
      );
    });

    this.worker.on('failed', (job, err) => {
      console.error(
        `[BullMQ] Job ${job?.id ?? 'unknown'} (${job?.name ?? 'unknown'}) failed:`,
        err.message,
      );
    });
  }

  async enqueuePush(
    data: NotificationJobData,
    options: { delayMs?: number; jobId?: string } = {},
  ): Promise<{ jobId: string; queued: boolean; directResult?: PushSendResult }> {
    if (!this.queue) {
      const directResult = await this.pushService.sendToUser(data.uid, data.payload);
      return { jobId: `direct-${Date.now()}`, queued: false, directResult };
    }

    const job = await this.queue.add('send-push', data, {
      delay: options.delayMs && options.delayMs > 0 ? options.delayMs : undefined,
      jobId: options.jobId,
    });
    return { jobId: String(job.id), queued: true };
  }

  async enqueueReminder(
    data: NotificationJobData,
    scheduledAt: Date,
  ): Promise<{ jobId: string; delayMs: number; queued: boolean }> {
    const delayMs = Math.max(0, scheduledAt.getTime() - Date.now());
    if (!this.queue) {
      await this.pushService.sendToUser(data.uid, data.payload);
      return { jobId: `direct-reminder-${Date.now()}`, delayMs: 0, queued: false };
    }

    const job = await this.queue.add('maintenance-reminder', data, {
      delay: delayMs > 0 ? delayMs : undefined,
    });
    return { jobId: String(job.id), delayMs, queued: true };
  }

  async getStatus(): Promise<QueueStatusSnapshot> {
    if (!this.queue) {
      return {
        enabled: false,
        waiting: 0,
        active: 0,
        delayed: 0,
        completed: 0,
        failed: 0,
      };
    }

    const counts = await this.queue.getJobCounts(
      'waiting',
      'active',
      'delayed',
      'completed',
      'failed',
    );

    return {
      enabled: true,
      waiting: counts.waiting ?? 0,
      active: counts.active ?? 0,
      delayed: counts.delayed ?? 0,
      completed: counts.completed ?? 0,
      failed: counts.failed ?? 0,
    };
  }

  async close(): Promise<void> {
    await this.worker?.close();
    await this.queue?.close();
    await this.workerConnection?.quit();
    await this.queueConnection?.quit();
  }
}
