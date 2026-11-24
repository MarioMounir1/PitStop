# PitStop Backend (Node.js + Firebase Firestore & Auth)

Express + TypeScript REST API backed by **Firebase Admin SDK (Cloud Firestore + Firebase Auth)** for PitStop's cloud sync and multi-device persistence.

## Data Model (Firestore)

All documents are scoped per authenticated Firebase user under `users/{uid}/`:

- `users/{uid}/vehicles/{id}`
- `users/{uid}/maintenanceRecords/{id}`
- `users/{uid}/fuelLogs/{id}`
- `users/{uid}/expenses/{id}`

## Endpoints

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| `GET` | `/api/health` | Public | Health check |
| `GET/POST` | `/api/vehicles` | Bearer | List or create/upsert vehicle |
| `PATCH/DELETE` | `/api/vehicles/:id` | Bearer | Update or cascade-delete vehicle |
| `GET/POST` | `/api/maintenance` | Bearer | List (`?vehicleId=`) or upsert service record |
| `PATCH/DELETE` | `/api/maintenance/:id` | Bearer | Update or delete service record |
| `GET/POST` | `/api/fuel` | Bearer | List (`?vehicleId=`) or upsert fuel log |
| `PATCH/DELETE` | `/api/fuel/:id` | Bearer | Update or delete fuel log |
| `GET/POST` | `/api/expenses` | Bearer | List (`?vehicleId=`) or upsert expense |
| `PATCH/DELETE` | `/api/expenses/:id` | Bearer | Update or delete expense |
| `POST` | `/api/sync/push` | Bearer | Batch-push full local Drift snapshot to Firestore |
| `GET` | `/api/sync/pull` | Bearer | Pull full user snapshot in Drift `BackupService` JSON format |

## Local Setup

```bash
cd backend
cp .env.example .env
# Fill in FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
# (or set GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json)

npm install
npm run dev
```

## Build & Test

```bash
npm run typecheck
npm test
npm run build
```

## Deploy Firestore Rules & Indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```
