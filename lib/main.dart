import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'local/app_database.dart';
import 'local/local_sale_repository.dart';
import 'auth_gate.dart';
import 'services/sale_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/sync_listener.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final database = AppDatabase();

  final localSaleRepository = LocalSaleRepository(database);

  final saleService = SaleService(
    firestore: FirebaseFirestore.instance,
    localRepository: localSaleRepository,
  );

  final syncService = SyncService(
    localRepository: localSaleRepository,
    saleService: saleService,
  );

  runApp(
    SyncListener(
      syncService: syncService,
      child: MyApp(saleService: saleService, database: database),
    ),
  );
}

class MyApp extends StatelessWidget {
  final SaleService saleService;
  final AppDatabase database;

  const MyApp({super.key, required this.saleService, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Abu Hashem Shop',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: AuthGate(saleService: saleService, database: database),
    );
  }
}
