# Shop Manager

Flutter application for shop sales, inventory, customers, debt tracking, expenses, reports, and activity history. Firebase Authentication and Cloud Firestore provide shared shop data; Drift/SQLite queues sales while the device is offline.

## Project Overview

- Mobile, web, macOS, and Windows Flutter clients.
- Firestore collections for users, products, purchase batches, sales, customers, debt payments, expenses, stock movements, and activity logs.
- Trusted callable Cloud Functions perform sales, debt collection, stock intake, and invoice cancellation as atomic Firestore transactions.
- Private cost/profit fields are stored separately in owner-readable `saleFinancials` documents; worker-readable invoice records contain sale details only.

## Features

- Owner and worker accounts; inactive accounts are denied by Firestore rules and callable functions.
- Cash and customer-credit sales with FIFO purchase-batch cost accounting.
- Offline sales saved locally and synchronized after connectivity returns. The same Firebase account must be signed in to synchronize a queued sale.
- Debt payments are distributed across a customer's oldest active invoices.
- Owners can add stock and cancel eligible invoices through server-side transactions.
- Workers can read shop data and add customers, while financial and stock records are written by trusted functions.
- Owner reports, expenses, customer statements, PDF export, and activity logs.

## Local learning setup (no billing)

The app can run against the Firebase Local Emulator Suite. This keeps sign-in, Firestore data, and Cloud Functions on your computer. It does not deploy anything or modify the live Firebase project.

1. Install Flutter, Node.js 22, Java 21, and the Firebase CLI.
2. From the project root, install the app and function dependencies:

   ```powershell
   flutter pub get
   npm ci --prefix functions
   ```

3. Start the local Auth, Firestore, and Functions emulators:

   ```powershell
   firebase emulators:start --project abu-hashem-shop-cf4fc --only auth,firestore,functions
   ```

   The Firebase CLI needs Java 21 for the Firestore emulator. On Windows, if Android Studio is installed, its bundled Java can be used in the same PowerShell window:

   ```powershell
   $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
   $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
   ```

   The emulator dashboard is at <http://127.0.0.1:4000>. Emulator data is temporary unless you export it.

4. In the dashboard, create a test account under Authentication. Then in Firestore, add a document at `users/{that-account-uid}` with fields such as `role: "owner"`, `isActive: true`, and `name: "Test Owner"`. This user exists only in the local emulator. Add products in the app after signing in.
5. In a second PowerShell window, run the Windows app with emulator routing enabled:

   ```powershell
   flutter run -d windows --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
   ```

   Run the app using this command when learning locally. A normal `flutter run` uses the Firebase project configured in `lib/firebase_options.dart`.

## Local checks

Run Firestore security-rule tests against the emulator:

```powershell
firebase emulators:exec --project demo-shop-manager-rules --only firestore "npm --prefix functions run test:rules"
```

Build the Functions TypeScript source and check dependency advisories:

```powershell
npm --prefix functions run build
npm --prefix functions audit
```

## Deployment notes

This learning workflow does not require changing the Firebase billing plan. Cloud Functions are run locally in the emulator. Do not run `firebase deploy` as part of the local workflow.

If the app is ever intentionally deployed, historical sale cost fields must first be moved into `saleFinancials`. The migration command defaults to a read-only dry run and requires two matching project settings before writing. Review the counts before any future migration. Firestore rules cannot hide selected fields inside a document, so old cost/profit values must be removed from worker-readable sale documents. Deploy the rules and functions before releasing a client that calls the new functions; older clients that still write sales, payments, stock intake, or cancellations directly will be denied those operations.

## Dependencies

- FlutterFire: `firebase_core`, `firebase_auth`, and `cloud_firestore`.
- `http` sends authenticated callable requests on all configured client platforms, including Windows.
- `connectivity_plus`, `drift`, `sqlite3_flutter_libs`, `path_provider`, and `path` support offline sales.
- `pdf` and `printing` create and share customer statements.
- Cloud Functions use `firebase-admin` and `firebase-functions` in the `functions/` directory.
- Firestore rule tests use `@firebase/rules-unit-testing` and the Firebase Emulator Suite.
