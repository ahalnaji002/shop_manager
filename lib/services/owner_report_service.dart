import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_report_data.dart';

class OwnerReportService {
  final FirebaseFirestore firestore;
  OwnerReportService({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  Stream<OwnerReportData> watchReport(OwnerReportDateRange range) {
    final controller = StreamController<OwnerReportData>();
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    QuerySnapshot<Map<String, dynamic>>? sales,
        financials,
        payments,
        expenses,
        allDebtSales;

    void emit() {
      if (sales == null ||
          financials == null ||
          payments == null ||
          expenses == null ||
          allDebtSales == null ||
          controller.isClosed) {
        return;
      }
      controller.add(
        _calculate(sales!, financials!, payments!, expenses!, allDebtSales!),
      );
    }

    void listen(
      Stream<QuerySnapshot<Map<String, dynamic>>> stream,
      void Function(QuerySnapshot<Map<String, dynamic>>) assign,
    ) {
      subscriptions.add(
        stream.listen((value) {
          assign(value);
          emit();
        }, onError: controller.addError),
      );
    }

    controller.onListen = () {
      final start = Timestamp.fromDate(range.start),
          end = Timestamp.fromDate(range.end);
      listen(
        firestore
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end)
            .snapshots(),
        (v) => sales = v,
      );
      listen(
        firestore
            .collection('saleFinancials')
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end)
            .snapshots(),
        (v) => financials = v,
      );
      listen(
        firestore
            .collection('debtPayments')
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end)
            .snapshots(),
        (v) => payments = v,
      );
      listen(
        firestore
            .collection('expenses')
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end)
            .snapshots(),
        (v) => expenses = v,
      );
      listen(
        firestore
            .collection('sales')
            .where('paymentType', isEqualTo: 'debt')
            .snapshots(),
        (v) => allDebtSales = v,
      );
    };
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await controller.close();
    };
    return controller.stream;
  }

  OwnerReportData _calculate(
    QuerySnapshot<Map<String, dynamic>> sales,
    QuerySnapshot<Map<String, dynamic>> financials,
    QuerySnapshot<Map<String, dynamic>> payments,
    QuerySnapshot<Map<String, dynamic>> expenses,
    QuerySnapshot<Map<String, dynamic>> allDebtSales,
  ) {
    final financialBySaleId = {
      for (final document in financials.docs) document.id: document.data(),
    };
    double netSales = 0, cogs = 0, cashSales = 0, debtSales = 0;
    int activeCount = 0, cancelledCount = 0;
    for (final document in sales.docs) {
      final data = document.data();
      if ((data['status'] ?? 'active') == 'cancelled') {
        cancelledCount++;
        continue;
      }
      final amount = _number(data['totalAmount']);
      netSales += amount;
      cogs += _number(financialBySaleId[document.id]?['totalCost']);
      activeCount++;
      if ((data['paymentType'] ?? 'cash') == 'debt') {
        debtSales += amount;
      } else {
        cashSales += amount;
      }
    }
    var operatingExpenses = 0.0;
    for (final document in expenses.docs) {
      operatingExpenses += _number(document.data()['amount']);
    }
    var collections = 0.0;
    for (final document in payments.docs) {
      final data = document.data();
      if (data['status'] == 'active') collections += _number(data['amount']);
    }
    var receivables = 0.0;
    for (final document in allDebtSales.docs) {
      final data = document.data();
      if ((data['status'] ?? 'active') != 'cancelled') {
        receivables += _number(data['remainingDebt']);
      }
    }
    final grossProfit = netSales - cogs;
    final netProfit = grossProfit - operatingExpenses;
    return OwnerReportData(
      netSales: netSales,
      costOfGoodsSold: cogs,
      grossProfit: grossProfit,
      operatingExpenses: operatingExpenses,
      netOperatingProfit: netProfit,
      grossMargin: netSales == 0 ? 0 : grossProfit / netSales * 100,
      netMargin: netSales == 0 ? 0 : netProfit / netSales * 100,
      activeInvoiceCount: activeCount,
      cancelledInvoiceCount: cancelledCount,
      averageActiveInvoiceValue: activeCount == 0 ? 0 : netSales / activeCount,
      cashSales: cashSales,
      debtSales: debtSales,
      activeDebtCollections: collections,
      netDebtMovement: debtSales - collections,
      currentOutstandingReceivables: receivables,
    );
  }

  double _number(dynamic value) => value is num ? value.toDouble() : 0;
}
