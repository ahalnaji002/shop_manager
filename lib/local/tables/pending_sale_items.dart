import 'package:drift/drift.dart';

class PendingSaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get saleId => text()();

  TextColumn get productId => text()();

  TextColumn get productName => text()();

  IntColumn get quantity => integer()();

  RealColumn get salePrice => real()();
}
