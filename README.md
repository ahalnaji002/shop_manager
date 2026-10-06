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
- Historical sale cost fields must be moved into `saleFinancials` before deploying the stricter rules. The migration command defaults to a read-only dry run and requires two matching project settings before writing.
- Owner reports, expenses, customer statements, PDF export, and activity logs.

## Setup

1. Install Flutter, Node.js 22, and the Firebase CLI.
2. Run `flutter pub get` from the project root.
3. Run `npm --prefix functions install` to install the callable-function dependencies.
4. Authenticate with Firebase CLI and select the intended project before deployment.
5. Run the rule tests against the local Firestore emulator:

   ```powershell
   firebase emulators:exec --project demo-shop-manager-rules --only firestore "npm --prefix functions run test:rules"
   ```

6. Build the function source with `npm --prefix functions run build`.
7. Before deployment, run the financial migration dry run with `GCLOUD_PROJECT` set to the intended project:

   ```powershell
   $env:GCLOUD_PROJECT = "your-project-id"
   npm --prefix functions run migrate:sale-financials
   ```

   Review the counts. To apply the migration, set `CONFIRM_SHOP_MIGRATION` to the exact same project ID and add `-- --apply` to the command. The script uses Application Default Credentials; it does not use a downloaded service-account key.
8. To publish after reviewing the migration output and billing plan, deploy with `firebase deploy --only firestore:rules,functions`.

Cloud Functions deployment requires a Firebase project on the Blaze plan. The local emulator and rule tests do not write to production. Run the historical migration before deploying the rules: Firestore rules cannot hide selected fields inside a document, so old cost/profit values must be removed from worker-readable sale documents. Deploy the rules and functions before releasing a client that calls the new functions; older clients that still write sales, payments, stock intake, or cancellations directly will be denied those operations.

## Dependencies

- FlutterFire: `firebase_core`, `firebase_auth`, and `cloud_firestore`.
- `http` sends authenticated callable requests on all configured client platforms, including Windows.
- `connectivity_plus`, `drift`, `sqlite3_flutter_libs`, `path_provider`, and `path` support offline sales.
- `pdf` and `printing` create and share customer statements.
- Cloud Functions use `firebase-admin` and `firebase-functions` in the `functions/` directory.
- Firestore rule tests use `@firebase/rules-unit-testing` and the Firebase Emulator Suite.
