import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  type Transaction,
} from "firebase-admin/firestore";
import {HttpsError, onCall, type CallableRequest} from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const MAX_SALE_LINES = 30;
const MAX_TRANSACTION_WRITES = 450;

type Role = "owner" | "worker";
type CartLine = {productId: string; quantity: number; salePrice: number};

async function requireShopUser(request: CallableRequest<unknown>): Promise<{uid: string; role: Role}> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "سجّل الدخول أولاً.");

  const user = await db.collection("users").doc(uid).get();
  const data = user.data();
  const role = data?.role;
  if (!user.exists || !data || data.isActive !== true || (role !== "owner" && role !== "worker")) {
    throw new HttpsError("permission-denied", "الحساب غير مفعّل أو لا يملك صلاحية.");
  }
  return {uid, role};
}

function record(data: unknown, name: string): Record<string, unknown> {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new HttpsError("invalid-argument", `بيانات ${name} غير صحيحة.`);
  }
  return data as Record<string, unknown>;
}

function nonEmptyString(value: unknown, name: string, max = 180): string {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > max) {
    throw new HttpsError("invalid-argument", `قيمة ${name} غير صحيحة.`);
  }
  return value.trim();
}

function positiveInteger(value: unknown, name: string): number {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) {
    throw new HttpsError("invalid-argument", `قيمة ${name} يجب أن تكون عدداً صحيحاً موجباً.`);
  }
  return value as number;
}

function positiveMoney(value: unknown, name: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
    throw new HttpsError("invalid-argument", `قيمة ${name} يجب أن تكون أكبر من صفر.`);
  }
  return value;
}

function safeTransactionSize(writes: number): void {
  if (writes > MAX_TRANSACTION_WRITES) {
    throw new HttpsError("resource-exhausted", "العملية كبيرة؛ قسّم البيع إلى عدد أقل من الأصناف أو الدفعات.");
  }
}

function writeActivity(
  tx: Transaction,
  uid: string,
  userName: string,
  type: string,
  description: string,
  referenceId: string,
  referenceType: string,
): void {
  const ref = db.collection("activityLogs").doc();
  tx.set(ref, {
    type,
    description,
    referenceId,
    referenceType,
    userId: uid,
    userName,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function userNameFrom(data: DocumentData | undefined): string {
  return typeof data?.name === "string" && data.name.trim() ? data.name.trim() : "غير معروف";
}

function parseSaleLines(value: unknown): CartLine[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_SALE_LINES) {
    throw new HttpsError("invalid-argument", "السلة فارغة أو تتجاوز الحد المسموح.");
  }
  const seen = new Set<string>();
  return value.map((raw) => {
    const item = record(raw, "الصنف");
    const productId = nonEmptyString(item.productId, "المنتج", 128);
    if (seen.has(productId)) throw new HttpsError("invalid-argument", "كرر المنتج في سطر واحد فقط.");
    seen.add(productId);
    const quantity = positiveInteger(item.quantity, "الكمية");
    const salePrice = positiveMoney(item.salePrice, "سعر البيع");
    return {productId, quantity, salePrice};
  });
}

function parseAllocations(value: unknown): Array<{batchId: string; quantity: number}> {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const allocation = record(raw, "توزيع الدفعة");
    return {
      batchId: nonEmptyString(allocation.batchId, "رقم الدفعة", 128),
      quantity: positiveInteger(allocation.quantity, "كمية الدفعة"),
    };
  });
}

export const completeSale = onCall(async (request) => {
  const {uid} = await requireShopUser(request);
  const data = record(request.data, "البيع");
  const saleId = nonEmptyString(data.saleId, "رقم الفاتورة", 128);
  const paymentType = data.paymentType;
  if (paymentType !== "cash" && paymentType !== "debt") {
    throw new HttpsError("invalid-argument", "نوع الدفع غير صحيح.");
  }
  const lines = parseSaleLines(data.cart);
  const customerId = paymentType === "debt" ? nonEmptyString(data.customerId, "العميل", 128) : null;
  const requestFingerprint = JSON.stringify({paymentType, customerId, lines});
  const saleRef = db.collection("sales").doc(saleId);
  const existingSale = await saleRef.get();
  if (existingSale.exists) {
    const previous = existingSale.data();
    if (previous?.createdBy === uid && previous.requestFingerprint === requestFingerprint) {
      return {saleId, alreadyCompleted: true};
    }
    throw new HttpsError("already-exists", "رقم الفاتورة مستخدم.");
  }

  // Read the candidate FIFO batches before entering the transaction. Every selected
  // document is then re-read transactionally before any write is made.
  const productRefs = lines.map((line) => db.collection("products").doc(line.productId));
  const batchLists = await Promise.all(lines.map(async (line) => {
    const result = await db.collection("purchase_batches").where("productId", "==", line.productId).get();
    return result.docs
      .filter((doc) => Number(doc.data().remainingQuantity ?? 0) > 0)
      .sort((a, b) => {
        const at = a.data().createdAt as Timestamp | undefined;
        const bt = b.data().createdAt as Timestamp | undefined;
        return (at?.toMillis() ?? 0) - (bt?.toMillis() ?? 0);
      });
  }));
  const uniqueBatchRefs = new Map<string, DocumentReference<DocumentData>>();
  const fifoCandidates = new Map<string, Array<{id: string; ref: DocumentReference<DocumentData>; quantity: number}>>();
  lines.forEach((line, index) => {
    let available = 0;
    const selected: Array<{id: string; ref: DocumentReference<DocumentData>; quantity: number}> = [];
    for (const batch of batchLists[index]) {
      const remaining = Number(batch.data().remainingQuantity ?? 0);
      if (!Number.isSafeInteger(remaining) || remaining <= 0) continue;
      selected.push({id: batch.id, ref: batch.ref, quantity: remaining});
      uniqueBatchRefs.set(batch.id, batch.ref);
      available += remaining;
    }
    fifoCandidates.set(line.productId, selected);
    if (available < line.quantity) throw new HttpsError("failed-precondition", "دفعات المخزون غير كافية.");
  });
  safeTransactionSize(1 + lines.length * 2 + (paymentType === "debt" ? 1 : 0) + 2);

  try {
    return await db.runTransaction(async (tx) => {
        const existingInTransaction = await tx.get(saleRef);
      if (existingInTransaction.exists) {
        const existingData = existingInTransaction.data();
        if (existingData?.createdBy === uid && existingData.requestFingerprint === requestFingerprint) {
          return {saleId, alreadyCompleted: true};
        }
        throw new HttpsError("already-exists", "رقم الفاتورة مستخدم.");
      }

      const productSnapshots = await Promise.all(productRefs.map((ref) => tx.get(ref)));
      const batchSnapshots = await Promise.all([...uniqueBatchRefs.values()].map((ref) => tx.get(ref)));
      const customerRef = customerId ? db.collection("customers").doc(customerId) : null;
      const customerSnapshot = customerRef ? await tx.get(customerRef) : null;
      const userSnapshot = await tx.get(db.collection("users").doc(uid));

      const products = new Map<string, DocumentData>();
      productSnapshots.forEach((snapshot, index) => {
        if (!snapshot.exists) throw new HttpsError("not-found", "أحد المنتجات لم يعد موجوداً.");
        products.set(lines[index].productId, snapshot.data()!);
      });
      const batches = new Map<string, DocumentSnapshot<DocumentData>>();
      batchSnapshots.forEach((snapshot) => batches.set(snapshot.id, snapshot));

      if (customerSnapshot && !customerSnapshot.exists) throw new HttpsError("not-found", "العميل غير موجود.");

      let totalAmount = 0;
      let totalCost = 0;
      const prepared: Array<{line: CartLine; product: DocumentData; item: DocumentData; allocations: Array<{ref: DocumentReference<DocumentData>; remaining: number}>}> = [];
      for (const line of lines) {
        const product = products.get(line.productId)!;
        const currentStock = Number(product.currentStock ?? 0);
        const salePrice = Number(product.salePrice ?? 0);
        if (!Number.isSafeInteger(currentStock) || currentStock < line.quantity) {
          throw new HttpsError("failed-precondition", "المخزون غير كافٍ.");
        }
        if (!Number.isFinite(salePrice) || salePrice <= 0 || Math.abs(salePrice - line.salePrice) > 0.000001) {
          throw new HttpsError("failed-precondition", "تغيّر سعر أحد المنتجات؛ حدّث السلة وحاول مجدداً.");
        }

        let left = line.quantity;
        let itemCost = 0;
        const allocations: Array<{ref: DocumentReference<DocumentData>; remaining: number}> = [];
        const itemAllocations: Array<{ref: DocumentReference<DocumentData>; quantity: number; unitCost: number; remaining: number}> = [];
        for (const candidate of fifoCandidates.get(line.productId) ?? []) {
          if (left === 0) break;
          const snapshot = batches.get(candidate.id);
          if (!snapshot?.exists) continue;
          const batch = snapshot.data()!;
          const remaining = Math.min(Number(batch.remainingQuantity ?? 0), candidate.quantity);
          const unitCost = Number(batch.purchasePrice ?? 0);
          if (!Number.isSafeInteger(remaining) || remaining <= 0 || !Number.isFinite(unitCost) || unitCost < 0) continue;
          const used = Math.min(left, remaining);
          left -= used;
          itemCost += used * unitCost;
          allocations.push({ref: candidate.ref, remaining: Number(batch.remainingQuantity ?? 0) - used});
          itemAllocations.push({ref: candidate.ref, quantity: used, unitCost, remaining: Number(batch.remainingQuantity ?? 0) - used});
        }
        if (left > 0) throw new HttpsError("failed-precondition", "دفعات المخزون غير كافية.");

        const itemSaleTotal = line.quantity * salePrice;
        totalAmount += itemSaleTotal;
        totalCost += itemCost;
        prepared.push({
          line,
          product,
          allocations,
          item: {
            productId: line.productId,
            productName: String(product.name ?? ""),
            quantity: line.quantity,
            unitSalePrice: salePrice,
            totalSale: itemSaleTotal,
            totalCost: itemCost,
            profit: itemSaleTotal - itemCost,
            batchAllocations: itemAllocations.map((allocation) => ({batchId: allocation.ref.id, quantity: allocation.quantity, unitCost: allocation.unitCost})),
          },
        });
      }

      safeTransactionSize(1 + prepared.length * 3 + prepared.reduce((n, p) => n + p.allocations.length, 0) + (customerRef ? 1 : 0) + 2);
      const privateItems: Record<string, DocumentData> = {};
      for (const entry of prepared) {
        tx.update(db.collection("products").doc(entry.line.productId), {
          currentStock: Number(entry.product.currentStock ?? 0) - entry.line.quantity,
          updatedAt: FieldValue.serverTimestamp(),
        });
        for (const allocation of entry.allocations) {
          tx.update(allocation.ref, {remainingQuantity: allocation.remaining});
        }
        tx.set(db.collection("stockMovements").doc(), {
          productId: entry.line.productId,
          type: "sale",
          direction: "out",
          quantity: entry.line.quantity,
          referenceType: "sale",
          referenceId: saleId,
          createdBy: uid,
          createdAt: FieldValue.serverTimestamp(),
        });
        const itemRef = saleRef.collection("items").doc();
        tx.set(itemRef, {
          productId: entry.item.productId,
          productName: entry.item.productName,
          quantity: entry.item.quantity,
          unitSalePrice: entry.item.unitSalePrice,
          totalSale: entry.item.totalSale,
        });
        privateItems[itemRef.id] = {
          totalCost: entry.item.totalCost,
          profit: entry.item.profit,
          batchAllocations: entry.item.batchAllocations,
        };
      }
      if (customerRef && customerSnapshot) {
        tx.update(customerRef, {
          currentDebt: Number(customerSnapshot.data()?.currentDebt ?? 0) + totalAmount,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      tx.set(saleRef, {
        paymentType,
        customerId,
        customerName: customerSnapshot?.data()?.name ?? null,
        totalAmount,
        remainingDebt: paymentType === "debt" ? totalAmount : 0,
        createdBy: uid,
        requestFingerprint,
        createdAt: FieldValue.serverTimestamp(),
        status: "active",
      });
      tx.set(db.collection("saleFinancials").doc(saleId), {
        totalCost,
        totalProfit: totalAmount - totalCost,
        status: "active",
        createdAt: FieldValue.serverTimestamp(),
        items: privateItems,
      });
      writeActivity(tx, uid, userNameFrom(userSnapshot.data()), "sale_created", paymentType === "debt" ? "تم تسجيل بيع بالدين" : "تم تسجيل بيع نقدي", saleId, "sale");
      return {saleId, alreadyCompleted: false};
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("failed-precondition", "تعذر إتمام البيع بسبب تغيّر بيانات المخزون. حدّث البيانات وحاول مجدداً.");
  }
});

export const addDebtPayment = onCall(async (request) => {
  const {uid} = await requireShopUser(request);
  const data = record(request.data, "دفعة الدين");
  const customerId = nonEmptyString(data.customerId, "العميل", 128);
  const paymentId = nonEmptyString(data.paymentId, "رقم الدفعة", 128);
  const amount = positiveMoney(data.amount, "المبلغ");
  const customerRef = db.collection("customers").doc(customerId);
  const paymentRef = db.collection("debtPayments").doc(paymentId);
  const existingPayment = await paymentRef.get();
  if (existingPayment.exists) {
    const previous = existingPayment.data();
    if (
      previous?.createdBy === uid &&
      previous.customerId === customerId &&
      Number(previous.amount) === amount
    ) return {paymentId};
    throw new HttpsError("already-exists", "رقم الدفعة مستخدم.");
  }
  const query = await db.collection("sales").where("customerId", "==", customerId).get();
  const debtSales = query.docs
    .filter((doc) => doc.data().paymentType === "debt" && (doc.data().status ?? "active") === "active")
    .sort((a, b) => {
      const at = a.data().createdAt as Timestamp | undefined;
      const bt = b.data().createdAt as Timestamp | undefined;
      return (at?.toMillis() ?? 0) - (bt?.toMillis() ?? 0);
    });
  if (debtSales.length > MAX_TRANSACTION_WRITES - 4) {
    throw new HttpsError("resource-exhausted", "عدد فواتير العميل كبير؛ يلزم تسوية الحساب على مراحل.");
  }
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const priorPayment = await tx.get(paymentRef);
    if (priorPayment.exists) {
      const previous = priorPayment.data();
      if (
        previous?.createdBy === uid &&
        previous.customerId === customerId &&
        Number(previous.amount) === amount
      ) return;
      throw new HttpsError("already-exists", "رقم الدفعة مستخدم.");
    }
    const customer = await tx.get(customerRef);
    const sales = await Promise.all(debtSales.map((sale) => tx.get(sale.ref)));
    const user = await tx.get(userRef);
    if (!customer.exists) throw new HttpsError("not-found", "العميل غير موجود.");
    const currentDebt = Number(customer.data()?.currentDebt ?? 0);
    if (!Number.isFinite(currentDebt) || amount > currentDebt + 0.001) {
      throw new HttpsError("failed-precondition", "المبلغ أكبر من الدين الحالي.");
    }
    let left = amount;
    const allocations: Array<{saleId: string; amount: number}> = [];
    const changes: Array<{ref: DocumentReference; remaining: number}> = [];
    for (let index = 0; index < debtSales.length && left > 0.001; index++) {
      const sale = sales[index];
      if (!sale.exists || (sale.data()?.status ?? "active") !== "active") continue;
      const remaining = Number(sale.data()?.remainingDebt ?? sale.data()?.totalAmount ?? 0);
      if (!Number.isFinite(remaining) || remaining <= 0) continue;
      const applied = Math.min(left, remaining);
      left -= applied;
      allocations.push({saleId: sale.id, amount: applied});
      changes.push({ref: debtSales[index].ref, remaining: Math.max(0, remaining - applied)});
    }
    if (left > 0.001) throw new HttpsError("failed-precondition", "رصيد العميل لا يطابق فواتير الدين.");
    for (const change of changes) tx.update(change.ref, {remainingDebt: change.remaining, updatedAt: FieldValue.serverTimestamp()});
    tx.update(customerRef, {currentDebt: Math.max(0, currentDebt - amount), updatedAt: FieldValue.serverTimestamp()});
    tx.set(paymentRef, {
      customerId,
      customerName: String(customer.data()?.name ?? ""),
      amount,
      allocations,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      status: "active",
    });
    writeActivity(tx, uid, userNameFrom(user.data()), "debt_payment_created", `تم تسجيل دفعة دين بقيمة ${amount.toFixed(2)} ₪`, paymentRef.id, "debtPayment");
  });
  return {paymentId: paymentRef.id};
});

export const addStock = onCall(async (request) => {
  const {uid, role} = await requireShopUser(request);
  if (role !== "owner") throw new HttpsError("permission-denied", "إضافة البضاعة متاحة للمالك فقط.");
  const data = record(request.data, "إضافة المخزون");
  const productId = nonEmptyString(data.productId, "المنتج", 128);
  const batchId = nonEmptyString(data.batchId, "رقم دفعة المخزون", 128);
  const quantity = positiveInteger(data.quantity, "الكمية");
  const purchasePrice = positiveMoney(data.purchasePrice, "سعر الشراء");
  const productRef = db.collection("products").doc(productId);
  const batchRef = db.collection("purchase_batches").doc(batchId);
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const priorBatch = await tx.get(batchRef);
    if (priorBatch.exists) {
      const previous = priorBatch.data();
      if (
        previous?.createdBy === uid &&
        previous.productId === productId &&
        Number(previous.quantityPurchased) === quantity &&
        Number(previous.purchasePrice) === purchasePrice
      ) return;
      throw new HttpsError("already-exists", "رقم دفعة المخزون مستخدم.");
    }
    const product = await tx.get(productRef);
    const user = await tx.get(userRef);
    if (!product.exists) throw new HttpsError("not-found", "المنتج غير موجود.");
    const stock = Number(product.data()?.currentStock ?? 0);
    if (!Number.isSafeInteger(stock) || stock + quantity > 2_000_000_000) throw new HttpsError("failed-precondition", "كمية المخزون غير صالحة.");
    tx.update(productRef, {currentStock: stock + quantity, updatedAt: FieldValue.serverTimestamp()});
    tx.set(batchRef, {
      productId,
      quantityPurchased: quantity,
      remainingQuantity: quantity,
      purchasePrice,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
    });
    writeActivity(tx, uid, userNameFrom(user.data()), "stock_added", `تمت إضافة ${quantity} قطعة للمخزون`, batchRef.id, "purchaseBatch");
  });
  return {batchId: batchRef.id};
});

export const cancelSale = onCall(async (request) => {
  const {uid, role} = await requireShopUser(request);
  if (role !== "owner") throw new HttpsError("permission-denied", "إلغاء الفاتورة متاح للمالك فقط.");
  const data = record(request.data, "إلغاء الفاتورة");
  const saleId = nonEmptyString(data.saleId, "رقم الفاتورة", 128);
  const saleRef = db.collection("sales").doc(saleId);
  const financialRef = db.collection("saleFinancials").doc(saleId);
  const itemsSnapshot = await saleRef.collection("items").get();
  if (itemsSnapshot.empty) throw new HttpsError("failed-precondition", "الفاتورة لا تحتوي على أصناف.");

  const existingFinancial = await financialRef.get();
  const existingPrivateItems = (existingFinancial.data()?.items ?? {}) as Record<string, DocumentData>;
  const itemRows = itemsSnapshot.docs.map((doc) => ({
    id: doc.id,
    ref: doc.ref,
    data: doc.data(),
    allocations: parseAllocations(existingPrivateItems[doc.id]?.batchAllocations ?? doc.data().batchAllocations),
  }));
  const productRefs = new Map<string, DocumentReference<DocumentData>>();
  const batchRefs = new Map<string, DocumentReference<DocumentData>>();
  for (const row of itemRows) {
    const productId = nonEmptyString(row.data.productId, "المنتج", 128);
    productRefs.set(productId, db.collection("products").doc(productId));
    for (const allocation of row.allocations) batchRefs.set(allocation.batchId, db.collection("purchase_batches").doc(allocation.batchId));
  }
  const allocationCount = itemRows.reduce((count, row) => count + row.allocations.length, 0);
  safeTransactionSize(4 + itemRows.length + productRefs.size + allocationCount);
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const sale = await tx.get(saleRef);
    const financial = await tx.get(financialRef);
    const items = await Promise.all(itemRows.map((row) => tx.get(row.ref)));
    const products = await Promise.all([...productRefs.values()].map((ref) => tx.get(ref)));
    const batches = await Promise.all([...batchRefs.values()].map((ref) => tx.get(ref)));
    const customerId = sale.data()?.customerId as string | null | undefined;
    const customerRef = customerId ? db.collection("customers").doc(customerId) : null;
    const customer = customerRef ? await tx.get(customerRef) : null;
    const user = await tx.get(userRef);
    if (!sale.exists) throw new HttpsError("not-found", "الفاتورة غير موجودة.");
    if ((sale.data()?.status ?? "active") === "cancelled") return;
    const saleData = sale.data()!;
    const totalAmount = Number(saleData.totalAmount ?? 0);
    const remainingDebt = Number(saleData.remainingDebt ?? (saleData.paymentType === "debt" ? totalAmount : 0));
    if (saleData.paymentType === "debt" && remainingDebt < totalAmount - 0.001) {
      throw new HttpsError("failed-precondition", "لا يمكن إلغاء فاتورة سُدّد جزء منها.");
    }
    if (items.some((item) => !item.exists)) throw new HttpsError("failed-precondition", "أصناف الفاتورة تغيّرت.");
    const productMap = new Map<string, DocumentSnapshot<DocumentData>>([...productRefs.keys()].map((id, i) => [id, products[i]]));
    const batchMap = new Map<string, DocumentSnapshot<DocumentData>>([...batchRefs.keys()].map((id, i) => [id, batches[i]]));
    if ([...productMap.values()].some((doc) => !doc.exists) || [...batchMap.values()].some((doc) => !doc.exists)) {
      throw new HttpsError("failed-precondition", "بيانات المنتج أو الدفعة غير مكتملة.");
    }
    if (customerRef && (!customer?.exists || Number(customer.data()?.currentDebt ?? 0) + 0.001 < remainingDebt)) {
      throw new HttpsError("failed-precondition", "رصيد العميل لا يطابق رصيد الفاتورة.");
    }
    for (const row of itemRows) {
      const productId = String(row.data.productId);
      const quantity = positiveInteger(row.data.quantity, "كمية الفاتورة");
      const product = productMap.get(productId)!.data()!;
      tx.update(productRefs.get(productId)!, {currentStock: Number(product.currentStock ?? 0) + quantity, updatedAt: FieldValue.serverTimestamp()});
      for (const allocation of row.allocations) {
        const batchSnapshot = batchMap.get(allocation.batchId)!;
        const batch = batchSnapshot.data()!;
        const current = Number(batch.remainingQuantity ?? 0);
        const purchased = Number(batch.quantityPurchased ?? current + allocation.quantity);
        const next = current + allocation.quantity;
        if (!Number.isSafeInteger(current) || !Number.isSafeInteger(purchased) || next > purchased) {
          throw new HttpsError("failed-precondition", "كمية الدفعة بعد الإرجاع غير صالحة.");
        }
        tx.update(batchRefs.get(allocation.batchId)!, {remainingQuantity: next});
      }
      tx.set(db.collection("stockMovements").doc(), {
        productId,
        type: "sale_cancel",
        direction: "in",
        quantity,
        referenceType: "sale",
        referenceId: saleId,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    if (customerRef && customer && remainingDebt > 0) {
      tx.update(customerRef, {currentDebt: Math.max(0, Number(customer.data()?.currentDebt ?? 0) - remainingDebt), updatedAt: FieldValue.serverTimestamp()});
    }
    tx.update(saleRef, {status: "cancelled", remainingDebt: 0, cancelledAt: FieldValue.serverTimestamp(), cancelledBy: uid});
    const privateItems = (financial.data()?.items ?? Object.fromEntries(itemRows.map((row) => [row.id, {
      totalCost: row.data.totalCost ?? 0,
      profit: row.data.profit ?? 0,
      batchAllocations: row.data.batchAllocations ?? [],
    }]))) as Record<string, DocumentData>;
    tx.set(financialRef, {
      totalCost: Number(financial.data()?.totalCost ?? saleData.totalCost ?? 0),
      totalProfit: Number(financial.data()?.totalProfit ?? saleData.totalProfit ?? 0),
      status: "cancelled",
      createdAt: financial.data()?.createdAt ?? saleData.createdAt ?? FieldValue.serverTimestamp(),
      items: privateItems,
    }, {merge: true});
    writeActivity(tx, uid, userNameFrom(user.data()), "sale_cancelled", "تم إلغاء فاتورة", saleId, "sale");
  });
  return {saleId};
});
