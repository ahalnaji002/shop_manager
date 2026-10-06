import 'app_database.dart';

import 'package:drift/drift.dart';

class LocalSaleRepository {
  final AppDatabase db;

  LocalSaleRepository(this.db);

  Future<void> savePendingSale({
    required String saleId,
    required DateTime createdAt,
    required String paymentType,
    String? customerId,
    String? customerName,
    required double totalAmount,
    required String createdBy,
    required List<Map<String, dynamic>> items,
  }) async {
    await db.transaction(() async {
      await db
          .into(db.pendingSales)
          .insert(
            PendingSalesCompanion.insert(
              id: saleId,
              createdAt: createdAt,
              paymentType: paymentType,
              customerId: customerId == null
                  ? const Value.absent()
                  : Value(customerId),
              customerName: customerName == null
                  ? const Value.absent()
                  : Value(customerName),
              totalAmount: totalAmount,
              createdBy: createdBy,
            ),
          );

      for (final item in items) {
        await db
            .into(db.pendingSaleItems)
            .insert(
              PendingSaleItemsCompanion.insert(
                saleId: saleId,
                productId: item['productId'] as String,
                productName: item['name'] as String,
                quantity: item['quantity'] as int,
                salePrice: item['salePrice'] as double,
              ),
            );
      }
    });
  }

  Future<List<PendingSale>> getPendingSales() {
    return (db.select(
      db.pendingSales,
    )..where((tbl) => tbl.status.equals('pending'))).get();
  }

  Future<List<PendingSale>> getPendingSalesForUser(String userId) {
    return (db.select(db.pendingSales)..where(
          (tbl) => tbl.status.equals('pending') & tbl.createdBy.equals(userId),
        ))
        .get();
  }

  Future<List<PendingSaleItem>> getSaleItems(String saleId) {
    return (db.select(
      db.pendingSaleItems,
    )..where((tbl) => tbl.saleId.equals(saleId))).get();
  }

  Future<void> markAsSynced(String saleId) async {
    await (db.update(
      db.pendingSales,
    )..where((tbl) => tbl.id.equals(saleId))).write(
      const PendingSalesCompanion(
        status: Value('synced'),
        syncError: Value(null),
      ),
    );
  }

  Future<void> markAsFailed({
    required String saleId,
    required String error,
  }) async {
    await (db.update(
      db.pendingSales,
    )..where((tbl) => tbl.id.equals(saleId))).write(
      PendingSalesCompanion(
        status: const Value('failed'),
        syncError: Value(error),
      ),
    );
  }

  Future<void> deleteSale(String saleId) async {
    await db.transaction(() async {
      await (db.delete(
        db.pendingSaleItems,
      )..where((tbl) => tbl.saleId.equals(saleId))).go();

      await (db.delete(
        db.pendingSales,
      )..where((tbl) => tbl.id.equals(saleId))).go();
    });
  }

  Stream<List<PendingSale>> watchPendingSales() {
    return (db.select(
      db.pendingSales,
    )..where((tbl) => tbl.status.equals('pending'))).watch();
  }
}
