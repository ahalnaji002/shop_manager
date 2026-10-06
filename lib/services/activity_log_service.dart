import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityLogService {
  static Future<void> log({
    required String type,
    required String description,
    String? referenceId,
    String? referenceType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final userName =
      (userData?['name'] ?? 'غير معروف').toString();

      await FirebaseFirestore.instance
          .collection('activityLogs')
          .add({
        'type': type,
        'description': description,
        'referenceId': referenceId,
        'referenceType': referenceType,
        'userId': user.uid,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // ما نخلي فشل تسجيل النشاط يوقف العملية الأساسية.
    }
  }
}