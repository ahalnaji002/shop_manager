import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/pending_sale_items.dart';
import 'tables/pending_sales.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [PendingSales, PendingSaleItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(p.join(directory.path, 'shop_manager.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
