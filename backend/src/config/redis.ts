import IORedis, { RedisOptions } from 'ioredis';

export function getRedisUrl(): string | undefined {
  const url = process.env.REDIS_URL?.trim();
  return url && url.length > 0 ? url : undefined;
}

export function isRedisConfigured(): boolean {
  return Boolean(getRedisUrl());
}

/**
 * Returns BullMQ-compatible ioredis connection options.
 * BullMQ requires `maxRetriesPerRequest: null`.
 */
export function createRedisConnection(urlOverride?: string): IORedis {
  const url = urlOverride ?? getRedisUrl() ?? 'redis://localhost:6379';
  const options: RedisOptions = {
    maxRetriesPerRequest: null,
    enableReadyCheck: false,
    lazyConnect: false,
  };
  return new IORedis(url, options);
}
