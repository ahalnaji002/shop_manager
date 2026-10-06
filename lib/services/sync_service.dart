import 'package:firebase_auth/firebase_auth.dart';

import '../local/local_sale_repository.dart';
import 'sale_service.dart';
import 'cloud_function_client.dart';

class SyncService {
  final LocalSaleRepository localRepository;
  final SaleService saleService;

  bool _isSyncing = false;

  SyncService({required this.localRepository, required this.saleService});

  Future<void> syncPendingSales() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final pendingSales = await localRepository.getPendingSalesForUser(
        user.uid,
      );

      for (final pendingSale in pendingSales) {
        try {
          final items = await localRepository.getSaleItems(pendingSale.id);

          final cart = items.map((item) {
            return <String, dynamic>{
              'productId': item.productId,
              'name': item.productName,
              'quantity': item.quantity,
              'salePrice': item.salePrice,
              'total': item.quantity * item.salePrice,
            };
          }).toList();

          final result = await saleService.completePendingSale(
            saleId: pendingSale.id,
            cart: cart,
            paymentType: pendingSale.paymentType,
            customerId: pendingSale.customerId,
            customerName: pendingSale.customerName,
            createdBy: pendingSale.createdBy,
          );

          if (result.isSynced) {
            await localRepository.markAsSynced(pendingSale.id);
          } else if (result.isFailed) {
            await localRepository.markAsFailed(
              saleId: pendingSale.id,
              error: result.message ?? 'Unknown sync error',
            );
          }
        } on FirebaseException catch (e) {
          if (e.code == 'unavailable' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'network-request-failed') {
            break;
          }

          await localRepository.markAsFailed(
            saleId: pendingSale.id,
            error: e.code,
          );
        } on CloudFunctionException catch (e) {
          if (e.code == 'unavailable' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'network-request-failed' ||
              e.code == 'unknown') {
            break;
          }
          await localRepository.markAsFailed(
            saleId: pendingSale.id,
            error: e.code,
          );
        } catch (e) {
          await localRepository.markAsFailed(
            saleId: pendingSale.id,
            error: e.toString(),
          );
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
