import { NextFunction, Request, Response } from 'express';
import { getFirebaseAuth } from '../config/firebase';

export interface AuthenticatedRequest extends Request {
  uid?: string;
}

export type TokenVerifier = (idToken: string) => Promise<{ uid: string }>;

/**
 * Express middleware verifying Firebase Auth ID tokens (`Authorization: Bearer <token>`).
 * In local development with `ALLOW_DEV_AUTH=true`, accepts an `x-dev-uid` header.
 */
export function createAuthMiddleware(verifier?: TokenVerifier) {
  return async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    const allowDevAuth = process.env.ALLOW_DEV_AUTH === 'true';
    const devUid = req.header('x-dev-uid');

    if (allowDevAuth && devUid && devUid.trim().length > 0) {
      req.uid = devUid.trim();
      next();
      return;
    }

    const authHeader = req.header('authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or invalid Authorization Bearer token.',
      });
      return;
    }

    const token = authHeader.slice('Bearer '.length).trim();
    if (!token) {
      res.status(401).json({
        error: 'Unauthorized',
        message: 'Empty Bearer token.',
      });
      return;
    }

    try {
      const verifyFn =
        verifier ?? ((t: string) => getFirebaseAuth().verifyIdToken(t));
      const decoded = await verifyFn(token);
      req.uid = decoded.uid;
      next();
    } catch {
      res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired Firebase ID token.',
      });
    }
  };
}
