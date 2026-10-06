const fs = require('node:fs');
const path = require('node:path');
const {after, before, test} = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc, updateDoc, serverTimestamp} = require('firebase/firestore');

let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-shop-manager-rules',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/owner-1'), {role: 'owner', isActive: true, name: 'Owner'}),
      setDoc(doc(db, 'users/worker-1'), {role: 'worker', isActive: true, name: 'Worker'}),
      setDoc(doc(db, 'users/inactive-1'), {role: 'worker', isActive: false}),
      setDoc(doc(db, 'products/product-1'), {name: 'Tea', salePrice: 5, currentStock: 10}),
      setDoc(doc(db, 'purchase_batches/batch-1'), {productId: 'product-1', remainingQuantity: 10}),
      setDoc(doc(db, 'sales/sale-1'), {paymentType: 'cash', totalAmount: 5, createdBy: 'worker-1'}),
      setDoc(doc(db, 'saleFinancials/sale-1'), {totalCost: 2, totalProfit: 3, status: 'active'}),
      setDoc(doc(db, 'customers/customer-1'), {name: 'Customer', phone: '', currentDebt: 5}),
    ]);
  });
});

after(async () => environment?.cleanup());

test('workers can read shop data but cannot bypass trusted financial writes', async () => {
  const db = environment.authenticatedContext('worker-1').firestore();
  await assertSucceeds(getDoc(doc(db, 'products/product-1')));
  await assertSucceeds(getDoc(doc(db, 'sales/sale-1')));
  await assertSucceeds(getDoc(doc(db, 'sales/sale-1/items/item-1')));
  await assertSucceeds(getDoc(doc(db, 'customers/customer-1')));

  await assertFails(setDoc(doc(db, 'sales/fake-sale'), {
    paymentType: 'debt', totalAmount: -500, remainingDebt: -500, status: 'active',
  }));
  await assertFails(setDoc(doc(db, 'sales/fake-sale/items/item-1'), {quantity: 1000, totalSale: -1}));
  await assertFails(setDoc(doc(db, 'debtPayments/fake-payment'), {amount: -500, customerId: 'customer-1'}));
  await assertFails(updateDoc(doc(db, 'customers/customer-1'), {currentDebt: 0}));
  await assertFails(updateDoc(doc(db, 'products/product-1'), {currentStock: 0}));
  await assertFails(updateDoc(doc(db, 'purchase_batches/batch-1'), {remainingQuantity: 0}));
  await assertFails(setDoc(doc(db, 'stockMovements/fake-movement'), {quantity: 1000, direction: 'in'}));
  await assertFails(getDoc(doc(db, 'expenses/secret-expense')));
  await assertFails(getDoc(doc(db, 'activityLogs/private-log')));
  await assertFails(getDoc(doc(db, 'saleFinancials/sale-1')));
  await assertFails(getDoc(doc(db, 'purchase_batches/batch-1')));
  await assertFails(getDoc(doc(db, 'users/owner-1')));
});

test('workers may add a zero-balance customer but cannot forge activity records', async () => {
  const db = environment.authenticatedContext('worker-1').firestore();
  await assertSucceeds(setDoc(doc(db, 'customers/new-customer'), {
    name: 'New Customer',
    phone: '',
    currentDebt: 0,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(db, 'activityLogs/worker-log'), {
    type: 'sale_created',
    description: 'Created sale',
    userId: 'worker-1',
    userName: 'Worker',
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(db, 'activityLogs/forged-log'), {
    type: 'sale_created',
    description: 'Forged sale',
    userId: 'owner-1',
    userName: 'Owner',
    createdAt: serverTimestamp(),
  }));
});

test('owners retain product and expense administration, while stock writes stay server-only', async () => {
  const db = environment.authenticatedContext('owner-1').firestore();
  await assertSucceeds(getDoc(doc(db, 'saleFinancials/sale-1')));
  await assertSucceeds(getDoc(doc(db, 'users/worker-1')));
  await assertSucceeds(setDoc(doc(db, 'products/new-product'), {name: 'Milk', currentStock: 0}));
  await assertSucceeds(updateDoc(doc(db, 'products/product-1'), {salePrice: 6}));
  await assertFails(updateDoc(doc(db, 'products/product-1'), {currentStock: 11}));
  await assertSucceeds(setDoc(doc(db, 'expenses/expense-1'), {title: 'Rent', amount: 10}));
  await assertFails(setDoc(doc(db, 'sales/direct-owner-sale'), {totalAmount: 10}));
});

test('inactive and unauthenticated users cannot read shop data', async () => {
  const inactive = environment.authenticatedContext('inactive-1').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(inactive, 'products/product-1')));
  await assertFails(getDoc(doc(anonymous, 'products/product-1')));
});
