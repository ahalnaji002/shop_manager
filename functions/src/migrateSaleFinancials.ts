import {initializeApp} from "firebase-admin/app";
import {FieldPath, FieldValue, getFirestore, type DocumentData, type DocumentReference, type QueryDocumentSnapshot} from "firebase-admin/firestore";

const projectId = process.env.GCLOUD_PROJECT;
if (!projectId) {
  throw new Error("Set GCLOUD_PROJECT explicitly to the Firebase project to inspect.");
}
const applyChanges = process.argv.includes("--apply");
if (applyChanges && process.env.CONFIRM_SHOP_MIGRATION !== projectId) {
  throw new Error("To apply writes, set CONFIRM_SHOP_MIGRATION to the exact GCLOUD_PROJECT value.");
}

initializeApp({projectId});
const db = getFirestore();
const pageSize = 100;
let last: QueryDocumentSnapshot<DocumentData> | undefined;
let inspected = 0;
let needingMigration = 0;

async function migrateSale(saleRef: DocumentReference<DocumentData>): Promise<boolean> {
  const itemQuery = await saleRef.collection("items").get();
  const financialRef = db.collection("saleFinancials").doc(saleRef.id);

  return db.runTransaction(async (tx) => {
    const sale = await tx.get(saleRef);
    const financial = await tx.get(financialRef);
    const items = await Promise.all(itemQuery.docs.map((item) => tx.get(item.ref)));
    if (!sale.exists) return false;

    const saleData = sale.data()!;
    const existingPrivateItems = (financial.data()?.items ?? {}) as Record<string, DocumentData>;
    const privateItems: Record<string, DocumentData> = {...existingPrivateItems};
    let itemCostTotal = 0;
    let itemProfitTotal = 0;
    let hasItemProfit = false;
    let hasLegacyFields =
      Object.hasOwn(saleData, "totalCost") || Object.hasOwn(saleData, "totalProfit");

    items.forEach((snapshot, index) => {
      if (!snapshot.exists) return;
      const itemData = snapshot.data()!;
      const oldPrivate = existingPrivateItems[snapshot.id] ?? {};
      const totalCost = Number(oldPrivate.totalCost ?? itemData.totalCost ?? 0);
      const profit = Number(oldPrivate.profit ?? itemData.profit ?? 0);
      hasItemProfit ||= Object.hasOwn(oldPrivate, "profit") || Object.hasOwn(itemData, "profit");
      itemCostTotal += totalCost;
      itemProfitTotal += profit;
      privateItems[snapshot.id] = {
        totalCost,
        profit,
        batchAllocations: oldPrivate.batchAllocations ?? itemData.batchAllocations ?? [],
      };
      if (["totalCost", "profit", "batchAllocations"].some((key) => Object.hasOwn(itemData, key))) {
        hasLegacyFields = true;
      }
    });

    const alreadyComplete = financial.exists &&
      Number.isFinite(Number(financial.data()?.totalCost)) &&
      Number.isFinite(Number(financial.data()?.totalProfit)) &&
      !hasLegacyFields;
    if (alreadyComplete) return false;

    if (applyChanges) {
      const totalCost = Number(financial.data()?.totalCost ?? saleData.totalCost ?? itemCostTotal);
      const totalProfit = Number(
        financial.data()?.totalProfit ??
          saleData.totalProfit ??
          (hasItemProfit ? itemProfitTotal : Number(saleData.totalAmount ?? 0) - totalCost),
      );
      tx.set(financialRef, {
        totalCost,
        totalProfit,
        status: saleData.status ?? "active",
        createdAt: financial.data()?.createdAt ?? saleData.createdAt ?? FieldValue.serverTimestamp(),
        items: privateItems,
      }, {merge: true});

      if (Object.hasOwn(saleData, "totalCost") || Object.hasOwn(saleData, "totalProfit")) {
        tx.update(saleRef, {
          totalCost: FieldValue.delete(),
          totalProfit: FieldValue.delete(),
        });
      }
      items.forEach((snapshot) => {
        if (!snapshot.exists) return;
        const itemData = snapshot.data()!;
        const fields: Record<string, FieldValue> = {};
        for (const key of ["totalCost", "profit", "batchAllocations"]) {
          if (Object.hasOwn(itemData, key)) fields[key] = FieldValue.delete();
        }
        if (Object.keys(fields).length > 0) tx.update(snapshot.ref, fields);
      });
    }
    return true;
  });
}

async function main(): Promise<void> {
  do {
    const sales = db.collection("sales").orderBy(FieldPath.documentId());
    const query = last ? sales.startAfter(last).limit(pageSize) : sales.limit(pageSize);
    const page = await query.get();
    for (const sale of page.docs) {
      inspected++;
      if (await migrateSale(sale.ref)) needingMigration++;
    }
    last = page.docs.at(-1);
  } while (last);

  console.log(`${applyChanges ? "Migrated" : "Would migrate"} ${needingMigration} of ${inspected} sales for ${projectId}.`);
  if (!applyChanges) console.log("Read-only dry run. Add --apply and CONFIRM_SHOP_MIGRATION=<project id> to write changes.");
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
