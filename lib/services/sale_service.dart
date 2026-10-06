import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../local/local_sale_repository.dart';
import 'cloud_function_client.dart';

class SaleService {
  final FirebaseFirestore firestore;
  final LocalSaleRepository localRepository;

  SaleService({required this.firestore, required this.localRepository});

  Future<SaleResult> completeSale({
    required List<Map<String, dynamic>> cart,
    required String paymentType,
    String? customerId,
    String? customerName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SaleResult.failed('المستخدم غير مسجل الدخول');
    }
    if (cart.isEmpty) {
      return const SaleResult.failed('السلة فارغة');
    }
    if (paymentType == 'debt' && customerId == null) {
      return const SaleResult.failed('اختر العميل');
    }

    final saleId = firestore.collection('sales').doc().id;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((result) => result == ConnectivityResult.none)) {
      await _saveLocally(
        saleId: saleId,
        cart: cart,
        paymentType: paymentType,
        customerId: customerId,
        customerName: customerName,
        userId: user.uid,
      );
      return SaleResult.pending(saleId);
    }

    try {
      await _submitSale(
        saleId: saleId,
        cart: cart,
        paymentType: paymentType,
        customerId: customerId,
        createdBy: user.uid,
      );
      return SaleResult.synced(saleId);
    } on CloudFunctionException catch (error) {
      if (_isNetworkError(error.code)) {
        await _saveLocally(
          saleId: saleId,
          cart: cart,
          paymentType: paymentType,
          customerId: customerId,
          customerName: customerName,
          userId: user.uid,
        );
        return SaleResult.pending(saleId);
      }
      return SaleResult.failed(error.message);
    } catch (error) {
      return SaleResult.failed('تعذر إتمام البيع: $error');
    }
  }

  Future<void> _submitSale({
    required String saleId,
    required List<Map<String, dynamic>> cart,
    required String paymentType,
    String? customerId,
    required String createdBy,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != createdBy) {
      throw const CloudFunctionException(
        'permission-denied',
        'سجّل الدخول بالحساب الذي أنشأ البيع دون اتصال لمزامنته.',
      );
    }
    await CloudFunctionClient.call('completeSale', {
      'saleId': saleId,
      'paymentType': paymentType,
      'customerId': customerId,
      'cart': cart
          .map(
            (item) => {
              'productId': item['productId'],
              'quantity': item['quantity'],
              'salePrice': (item['salePrice'] as num).toDouble(),
            },
          )
          .toList(),
    });
  }

  Future<void> _saveLocally({
    required String saleId,
    required List<Map<String, dynamic>> cart,
    required String paymentType,
    String? customerId,
    String? customerName,
    required String userId,
  }) async {
    final totalAmount = cart.fold<double>(
      0,
      (totalSoFar, item) =>
          totalSoFar +
          (item['quantity'] as num).toDouble() *
              (item['salePrice'] as num).toDouble(),
    );
    await localRepository.savePendingSale(
      saleId: saleId,
      createdAt: DateTime.now(),
      paymentType: paymentType,
      customerId: customerId,
      customerName: customerName,
      totalAmount: totalAmount,
      createdBy: userId,
      items: cart,
    );
  }

  bool _isNetworkError(String code) =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed' ||
      code == 'unknown';

  Future<SaleResult> completePendingSale({
    required String saleId,
    required List<Map<String, dynamic>> cart,
    required String paymentType,
    String? customerId,
    String? customerName,
    required String createdBy,
  }) async {
    try {
      await _submitSale(
        saleId: saleId,
        cart: cart,
        paymentType: paymentType,
        customerId: customerId,
        createdBy: createdBy,
      );
      return SaleResult.synced(saleId);
    } on CloudFunctionException catch (error) {
      if (_isNetworkError(error.code)) rethrow;
      return SaleResult.failed(error.message);
    } catch (error) {
      return SaleResult.failed('تعذر مزامنة البيع: $error');
    }
  }
}

class SaleResult {
  final String status;
  final String? saleId;
  final String? message;

  const SaleResult._({required this.status, this.saleId, this.message});
  const SaleResult.synced(String saleId)
    : this._(status: 'synced', saleId: saleId);
  const SaleResult.pending(String saleId)
    : this._(status: 'pending', saleId: saleId);
  const SaleResult.failed(String message)
    : this._(status: 'failed', message: message);

  bool get isSynced => status == 'synced';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}
