import 'dotenv/config';
import { createApp } from './app';
import { initFirebase } from './config/firebase';

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

const app = createApp();

app.listen(port, () => {
  console.log(`Torq Node.js + Firebase backend listening on http://localhost:${port}`);
});
