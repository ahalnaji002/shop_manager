import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../local/app_database.dart';
import '../services/sale_service.dart';
import '/screens/login_screen.dart';
import '/screens/owner_dashboard.dart';
import '/screens/worker_dashboard.dart';

class AuthGate extends StatelessWidget {
  final SaleService saleService;
  final AppDatabase database;

  const AuthGate({
    super.key,
    required this.saleService,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Scaffold(
                body: Center(child: Text('تعذر تحميل بيانات المستخدم')),
              );
            }

            final data = userSnapshot.data!.data()!;

            final isActive = data['isActive'] == true;

            final role = data['role'] ?? '';

            if (!isActive) {
              return const Scaffold(
                body: Center(child: Text('هذا الحساب موقوف')),
              );
            }

            if (role == 'owner') {
              return OwnerDashboard(
                saleService: saleService,
                database: database,
              );
            }

            if (role == 'worker') {
              return WorkerDashboard(
                saleService: saleService,
                database: database,
              );
            }

            return const Scaffold(
              body: Center(child: Text('صلاحية المستخدم غير معروفة')),
            );
          },
        );
      },
    );
  }
}
