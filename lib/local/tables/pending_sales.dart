import 'package:drift/drift.dart';

class PendingSales extends Table {
  TextColumn get id => text()();

  DateTimeColumn get createdAt => dateTime()();

  TextColumn get paymentType => text()();

  TextColumn get customerId => text().nullable()();

  TextColumn get customerName => text().nullable()();

  RealColumn get totalAmount => real()();

  TextColumn get createdBy => text()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
