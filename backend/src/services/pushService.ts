import crypto from 'crypto';
import admin from 'firebase-admin';
import { getFirestoreDb, initFirebase } from '../config/firebase';

export interface DeviceRegistration {
  token: string;
  platform: 'android' | 'ios' | 'web' | 'macos' | 'unknown';
  updatedAt: string;
}

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushSendResult {
  sent: number;
  failed: number;
  removedTokens: number;
}

export interface PushService {
  registerDevice(
    uid: string,
    token: string,
    platform: DeviceRegistration['platform'],
  ): Promise<void>;
  unregisterDevice(uid: string, token: string): Promise<void>;
  listDeviceTokens(uid: string): Promise<string[]>;
  sendToUser(uid: string, payload: PushPayload): Promise<PushSendResult>;
}

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex').slice(0, 32);
}

const INVALID_TOKEN_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

export class FirebasePushService implements PushService {
  private devicesCollection(uid: string) {
    return getFirestoreDb().collection('users').doc(uid).collection('devices');
  }

  async registerDevice(
    uid: string,
    token: string,
    platform: DeviceRegistration['platform'],
  ): Promise<void> {
    const docId = hashToken(token);
    await this.devicesCollection(uid).doc(docId).set(
      {
        token,
        platform,
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
  }

  async unregisterDevice(uid: string, token: string): Promise<void> {
    const docId = hashToken(token);
    await this.devicesCollection(uid).doc(docId).delete();
  }

  async listDeviceTokens(uid: string): Promise<string[]> {
    const snap = await this.devicesCollection(uid).get();
    return snap.docs
      .map((d) => d.data()?.token as string | undefined)
      .filter((t): t is string => Boolean(t && t.trim().length > 0));
  }

  async sendToUser(uid: string, payload: PushPayload): Promise<PushSendResult> {
    initFirebase();
    const tokens = await this.listDeviceTokens(uid);
    if (tokens.length === 0) {
      return { sent: 0, failed: 0, removedTokens: 0 };
    }

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data,
      android: {
        priority: 'high',
        notification: {
          channelId: 'pitstop_reminders',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    const staleTokens: string[] = [];
    response.responses.forEach((res, idx) => {
      if (!res.success && res.error && INVALID_TOKEN_CODES.has(res.error.code)) {
        staleTokens.push(tokens[idx]);
      }
    });

    if (staleTokens.length > 0) {
      await Promise.allSettled(
        staleTokens.map((t) => this.unregisterDevice(uid, t)),
      );
    }

    return {
      sent: response.successCount,
      failed: response.failureCount,
      removedTokens: staleTokens.length,
    };
  }
}
