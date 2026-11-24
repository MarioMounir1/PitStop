import admin from 'firebase-admin';

let initialized = false;

/**
 * Initializes the Firebase Admin SDK using either:
 * 1. Explicit env vars (`FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`), or
 * 2. Application Default Credentials (`GOOGLE_APPLICATION_CREDENTIALS`).
 */
export function initFirebase(): admin.app.App {
  if (initialized && admin.apps.length > 0) {
    return admin.app();
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

  if (projectId && clientEmail && privateKey) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      ...(projectId ? { projectId } : {}),
    });
  }

  initialized = true;
  return admin.app();
}

export function getFirestoreDb(): admin.firestore.Firestore {
  initFirebase();
  const db = admin.firestore();
  return db;
}

export function getFirebaseAuth(): admin.auth.Auth {
  initFirebase();
  return admin.auth();
}
