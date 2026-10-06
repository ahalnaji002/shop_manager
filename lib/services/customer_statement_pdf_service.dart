import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerStatementPdfService {
  static Future<Uint8List> buildPdf({
    required String customerId,
    required String customerName,
    required String phone,
    required double currentDebt,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // Arabic font stored locally for reliable offline PDF generation.
    final fontData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );
    final arabicFont = pw.Font.ttf(fontData);

    final salesSnapshot = await firestore
        .collection('sales')
        .where('customerId', isEqualTo: customerId)
        .where('paymentType', isEqualTo: 'debt')
        .get();

    final paymentsSnapshot = await firestore
        .collection('debtPayments')
        .where('customerId', isEqualTo: customerId)
        .get();

    final movements = <_StatementMovement>[];

    double totalDebtSales = 0;
    double totalPayments = 0;

    for (final saleDoc in salesSnapshot.docs) {
      final data = saleDoc.data();

      final status = (data['status'] ?? 'active').toString();

      if (status == 'cancelled') {
        continue;
      }

      final amount = ((data['totalAmount'] ?? 0) as num).toDouble();
      final createdAt = data['createdAt'] as Timestamp?;

      final itemsSnapshot = await saleDoc.reference
          .collection('items')
          .get();

      final items = itemsSnapshot.docs.map((itemDoc) {
        final item = itemDoc.data();

        return _StatementItem(
          name: (item['productName'] ?? '').toString(),
          quantity: ((item['quantity'] ?? 0) as num).toInt(),
          unitPrice: ((item['unitSalePrice'] ?? 0) as num).toDouble(),
          total: ((item['totalSale'] ?? 0) as num).toDouble(),
        );
      }).toList();

      totalDebtSales += amount;

      movements.add(
        _StatementMovement.sale(
          amount: amount,
          createdAt: createdAt?.toDate(),
          items: items,
        ),
      );
    }

    for (final paymentDoc in paymentsSnapshot.docs) {
      final data = paymentDoc.data();

      final amount = ((data['amount'] ?? 0) as num).toDouble();
      final createdAt = data['createdAt'] as Timestamp?;

      totalPayments += amount;

      movements.add(
        _StatementMovement.payment(
          amount: amount,
          createdAt: createdAt?.toDate(),
        ),
      );
    }

    movements.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    final document = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicFont,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'دكان أبو هاشم',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              'كشف حساب عميل',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 18),

          _infoRow('اسم العميل', customerName),
          if (phone.trim().isNotEmpty)
            _infoRow('رقم الهاتف', phone),

          _infoDateRow(
            'تاريخ الكشف',
            _formatDate(DateTime.now()),
          ),

          pw.SizedBox(height: 18),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey300,
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                _summaryRow(
                  'إجمالي المشتريات الآجلة',
                  totalDebtSales,
                ),
                pw.SizedBox(height: 7),
                _summaryRow(
                  'إجمالي الدفعات',
                  totalPayments,
                ),
                pw.Divider(),
                _summaryRow(
                  'الرصيد الحالي',
                  currentDebt,
                  bold: true,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          pw.Text(
            'الحركات',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 10),

          if (movements.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey300,
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'لا توجد حركات لهذا العميل',
                ),
              ),
            )
          else
            ...movements.map(_movementWidget),
        ],
      ),
    );

    return document.save();
  }

  static Future<void> preview({
    required String customerId,
    required String customerName,
    required String phone,
    required double currentDebt,
  }) async {
    final bytes = await buildPdf(
      customerId: customerId,
      customerName: customerName,
      phone: phone,
      currentDebt: currentDebt,
    );

    await Printing.layoutPdf(
      name: 'كشف حساب - $customerName',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> share({
    required String customerId,
    required String customerName,
    required String phone,
    required double currentDebt,
  }) async {
    final bytes = await buildPdf(
      customerId: customerId,
      customerName: customerName,
      phone: phone,
      currentDebt: currentDebt,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'customer_statement_$customerName.pdf',
    );
  }

  static pw.Widget _movementWidget(
      _StatementMovement movement,
      ) {
    final isSale = movement.type == _MovementType.sale;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                isSale ? 'فاتورة دين' : 'دفعة',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                isSale
                    ? 'مدين: ${movement.amount.toStringAsFixed(2)} شيكل'
                    : 'دفعة: ${movement.amount.toStringAsFixed(2)} شيكل',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Text(
              movement.createdAt == null
                  ? 'بدون تاريخ'
                  : _formatDate(movement.createdAt!),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          if (isSale && movement.items.isNotEmpty) ...[
            pw.SizedBox(height: 9),
            pw.Divider(),
            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.7,
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(0.8),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  children: [
                    _tableCell('#', bold: true),
                    _tableCell('الصنف', bold: true),
                    _tableCell('الكمية', bold: true),
                    _tableCell('السعر', bold: true),
                    _tableCell('المبلغ', bold: true),
                  ],
                ),

                ...movement.items.asMap().entries.map(
                      (entry) {
                    final index = entry.key + 1;
                    final item = entry.value;

                    return pw.TableRow(
                      children: [
                        _tableCell('$index'),
                        _tableCell(item.name),
                        _tableCell('${item.quantity}'),
                        _tableCell(
                          '${item.unitPrice.toStringAsFixed(2)} شيكل',
                        ),
                        _tableCell(
                          '${item.total.toStringAsFixed(2)} شيكل',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _infoRow(
      String title,
      String value,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$title:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoDateRow(
      String title,
      String value,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$title:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Directionality(
              textDirection: pw.TextDirection.ltr,
              child: pw.Text(value),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(
      String title,
      double value, {
        bool bold = false,
      }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '${value.toStringAsFixed(2)} شيكل',
          style: pw.TextStyle(
            fontWeight:
            bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day\u2011$month\u2011${date.year}';
  }

  static pw.Widget _tableCell(
      String text, {
        bool bold = false,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight:
          bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

enum _MovementType {
  sale,
  payment,
}

class _StatementMovement {
  final _MovementType type;
  final double amount;
  final DateTime? createdAt;
  final List<_StatementItem> items;

  const _StatementMovement._({
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.items,
  });

  factory _StatementMovement.sale({
    required double amount,
    required DateTime? createdAt,
    required List<_StatementItem> items,
  }) {
    return _StatementMovement._(
      type: _MovementType.sale,
      amount: amount,
      createdAt: createdAt,
      items: items,
    );
  }

  factory _StatementMovement.payment({
    required double amount,
    required DateTime? createdAt,
  }) {
    return _StatementMovement._(
      type: _MovementType.payment,
      amount: amount,
      createdAt: createdAt,
      items: const [],
    );
  }
}

class _StatementItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double total;

  const _StatementItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}