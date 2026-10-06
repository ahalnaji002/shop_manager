import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/customer_statement_pdf_service.dart';

class CustomerStatementScreen extends StatelessWidget {
  final String customerId;
  final String customerName;
  final String phone;
  final double currentDebt;

  const CustomerStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.currentDebt,
  });

  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          title: const Text(
            'كشف حساب العميل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await CustomerStatementPdfService.preview(
                        customerId: customerId,
                        customerName: customerName,
                        phone: phone,
                        currentDebt: currentDebt,
                      );
                    },
                    icon: const Icon(
                      Icons.picture_as_pdf_outlined,
                    ),
                    label: const Text(
                      'معاينة PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: const BorderSide(
                        color: Color(0xFFDDE2E8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await CustomerStatementPdfService.share(
                        customerId: customerId,
                        customerName: customerName,
                        phone: phone,
                        currentDebt: currentDebt,
                      );
                    },
                    icon: const Icon(
                      Icons.share_outlined,
                    ),
                    label: const Text(
                      'مشاركة PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sales')
              .where('customerId', isEqualTo: customerId)
              .where('paymentType', isEqualTo: 'debt')
              .snapshots(),
          builder: (context, salesSnapshot) {
            if (salesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (salesSnapshot.hasError) {
              return const Center(child: Text('تعذر تحميل كشف الحساب'));
            }

            final salesDocs = salesSnapshot.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('debtPayments')
                  .where('customerId', isEqualTo: customerId)
                  .snapshots(),
              builder: (context, paymentsSnapshot) {
                if (paymentsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final paymentDocs = paymentsSnapshot.data?.docs ?? [];

                final movements = <Map<String, dynamic>>[];

                for (final doc in salesDocs) {
                  final data = doc.data() as Map<String, dynamic>;

                  final status = data['status'] ?? 'active';

                  if (status == 'cancelled') {
                    continue;
                  }

                  movements.add({
                    'type': 'sale',
                    'id': doc.id,
                    'amount': ((data['totalAmount'] ?? 0) as num).toDouble(),
                    'createdAt': data['createdAt'] as Timestamp?,
                  });
                }

                for (final doc in paymentDocs) {
                  final data = doc.data() as Map<String, dynamic>;

                  movements.add({
                    'type': 'payment',
                    'id': doc.id,
                    'amount': ((data['amount'] ?? 0) as num).toDouble(),
                    'createdAt': data['createdAt'] as Timestamp?,
                  });
                }

                movements.sort((a, b) {
                  final aTime = a['createdAt'] as Timestamp?;

                  final bTime = b['createdAt'] as Timestamp?;

                  if (aTime == null && bTime == null) {
                    return 0;
                  }

                  if (aTime == null) {
                    return 1;
                  }

                  if (bTime == null) {
                    return -1;
                  }

                  return bTime.compareTo(aTime);
                });

                double totalDebtSales = 0;
                double totalPayments = 0;

                for (final movement in movements) {
                  final amount = movement['amount'] as double;

                  if (movement['type'] == 'sale') {
                    totalDebtSales += amount;
                  } else {
                    totalPayments += amount;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCustomerHeader(),

                      const SizedBox(height: 18),

                      _buildSummary(
                        totalDebtSales: totalDebtSales,
                        totalPayments: totalPayments,
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'الحركات',
                        style: TextStyle(
                          color: navy,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (movements.isEmpty)
                        _emptyCard()
                      else
                        ...movements.map((movement) {
                          if (movement['type'] == 'sale') {
                            return _buildSaleMovement(
                              saleId: movement['id'] as String,
                              amount: movement['amount'] as double,
                              createdAt: movement['createdAt'] as Timestamp?,
                            );
                          }

                          return _buildPaymentMovement(
                            amount: movement['amount'] as double,
                            createdAt: movement['createdAt'] as Timestamp?,
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFFFF4DA),
            child: Icon(Icons.person_rounded, color: navy, size: 32),
          ),

          const SizedBox(height: 10),

          Text(
            customerName,
            style: const TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(color: Color(0xFF7C8796), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary({
    required double totalDebtSales,
    required double totalPayments,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: 'إجمالي المشتريات الآجلة',
                value: '${totalDebtSales.toStringAsFixed(2)} ₪',
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _summaryCard(
                title: 'إجمالي الدفعات',
                value: '${totalPayments.toStringAsFixed(2)} ₪',
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _summaryCard(
          title: 'الرصيد الحالي',
          value: '${currentDebt.toStringAsFixed(2)} ₪',
          highlight: true,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF6E2) : Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF7C8796), fontSize: 11),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFD94C4C) : navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleMovement({
    required String saleId,
    required double amount,
    required Timestamp? createdAt,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.receipt_long_outlined, color: navy),
        title: const Text(
          'فاتورة دين',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(_formatTimestamp(createdAt)),
        trailing: Text(
          '+ ${amount.toStringAsFixed(2)} ₪',
          style: const TextStyle(
            color: Color(0xFFD94C4C),
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [_buildSaleItems(saleId)],
      ),
    );
  }

  Widget _buildSaleItems(String saleId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .doc(saleId)
          .collection('items')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Text('لا توجد أصناف'),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final name = (data['productName'] ?? '').toString();

              final quantity = ((data['quantity'] ?? 0) as num).toInt();

              final salePrice = ((data['unitSalePrice'] ?? 0) as num)
                  .toDouble();

              final total = ((data['totalSale'] ?? 0) as num).toDouble();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name, style: const TextStyle(color: navy)),
                    ),

                    Text(
                      '$quantity × '
                      '${salePrice.toStringAsFixed(2)} ₪',
                      style: const TextStyle(color: Color(0xFF7C8796)),
                    ),

                    const SizedBox(width: 12),

                    Text(
                      '${total.toStringAsFixed(2)} ₪',
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMovement({
    required double amount,
    required Timestamp? createdAt,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Colors.green),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'دفعة',
                  style: TextStyle(color: navy, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 3),

                Text(
                  _formatTimestamp(createdAt),
                  style: const TextStyle(
                    color: Color(0xFF8B95A3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '- ${amount.toStringAsFixed(2)} ₪',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Text(
          'لا توجد حركات لهذا العميل',
          style: TextStyle(color: Color(0xFF7C8796)),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'الآن';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
