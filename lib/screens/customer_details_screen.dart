import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'sale_details_screen.dart';

import 'package:drift/drift.dart' hide Column;

import '../local/app_database.dart';
import 'add_debt_payment_screen.dart';
import 'customer_statement_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String phone;
  final double currentDebt;
  final AppDatabase database;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.currentDebt,
    required this.database,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
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
          elevation: 0,
          title: const Text(
            'تفاصيل العميل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<List<PendingSale>>(
          stream:
              (widget.database.select(widget.database.pendingSales)..where(
                    (tbl) =>
                        tbl.status.equals('pending') &
                        tbl.paymentType.equals('debt') &
                        tbl.customerId.equals(widget.customerId),
                  ))
                  .watch(),
          builder: (context, pendingSnapshot) {
            final pendingSales = pendingSnapshot.data ?? [];

            double pendingDebt = 0;

            for (final sale in pendingSales) {
              pendingDebt += sale.totalAmount;
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .doc(widget.customerId)
                  .snapshots(),
              builder: (context, customerSnapshot) {
                if (customerSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (customerSnapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل بيانات العميل'));
                }

                if (!customerSnapshot.hasData ||
                    !customerSnapshot.data!.exists) {
                  return const Center(child: Text('العميل غير موجود'));
                }

                final customerData = customerSnapshot.data!.data()!;

                final String customerName =
                    customerData['name'] ?? widget.customerName;

                final String phone = customerData['phone'] ?? widget.phone;

                final double firestoreDebt =
                    ((customerData['currentDebt'] ?? 0) as num).toDouble();

                final double currentDebt = firestoreDebt + pendingDebt;

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCustomerCard(
                              customerName: customerName,
                              phone: phone,
                              currentDebt: currentDebt,
                            ),

                            const SizedBox(height: 14),

                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerStatementScreen(
                                        customerId: widget.customerId,
                                        customerName: customerName,
                                        phone: phone,
                                        currentDebt: currentDebt,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: navy,
                                  side: const BorderSide(
                                    color: Color(0xFFDDE2E8),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.description_outlined),
                                label: const Text(
                                  'كشف حساب',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            const SizedBox(height: 26),

                            _buildSectionTitle(
                              'المشتريات الآجلة',
                              Icons.receipt_long_outlined,
                            ),

                            const SizedBox(height: 12),

                            _buildDebtSales(),

                            if (pendingDebt > 0) ...[
                              const SizedBox(height: 12),
                              _buildPendingDebtCard(pendingDebt),
                            ],

                            const SizedBox(height: 26),

                            _buildSectionTitle(
                              'الدفعات',
                              Icons.payments_outlined,
                            ),

                            const SizedBox(height: 12),

                            _buildPayments(),
                          ],
                        ),
                      ),
                    ),

                    if (currentDebt > 0)
                      _buildPaymentButton(
                        currentDebt: currentDebt,
                        customerName: customerName,
                        hasPendingDebt: pendingDebt > 0,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPendingDebtCard(double pendingDebt) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D89C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: Color(0xFFE09B00)),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دين بانتظار المزامنة',
                  style: TextStyle(color: navy, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 3),
                Text(
                  'هذا المبلغ محفوظ على الجهاز ولم يصل للسحابة بعد',
                  style: TextStyle(color: Color(0xFF7C8796), fontSize: 11),
                ),
              ],
            ),
          ),

          Text(
            '+ ${pendingDebt.toStringAsFixed(2)} ₪',
            style: const TextStyle(
              color: Color(0xFFE09B00),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Customer Card
  // =========================================================

  Widget _buildCustomerCard({
    required String customerName,
    required String phone,
    required double currentDebt,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, size: 36, color: navy),
          ),

          const SizedBox(height: 12),

          Text(
            customerName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),

          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: Color(0xFF7C8796),
                ),
                const SizedBox(width: 5),
                Text(
                  phone,
                  style: const TextStyle(
                    color: Color(0xFF7C8796),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'إجمالي الدين الحالي',
                  style: TextStyle(color: Color(0xFF7C8796), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '${currentDebt.toStringAsFixed(2)} ₪',
                  style: TextStyle(
                    color: currentDebt > 0 ? const Color(0xFFD94C4C) : navy,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Section Title
  // =========================================================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: navy, size: 21),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // Debt Sales
  // =========================================================

  Widget _buildDebtSales() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .where('customerId', isEqualTo: widget.customerId)
          .where('paymentType', isEqualTo: 'debt')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _emptyCard('تعذر تحميل المشتريات');
        }

        final docs = List<QueryDocumentSnapshot>.from(
          snapshot.data?.docs ?? [],
        );

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) {
            return 0;
          }

          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return _emptyCard('لا توجد مشتريات آجلة');
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final double amount = ((data['totalAmount'] ?? 0) as num)
                .toDouble();

            final Timestamp? createdAt = data['createdAt'] as Timestamp?;

            final String date = _formatTimestamp(createdAt);

            // الضغط على الفاتورة يفتح تفاصيلها.
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SaleDetailsScreen(saleId: doc.id),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: navy,
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'فاتورة دين',
                              style: TextStyle(
                                color: navy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Color(0xFF8B95A3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+ ${amount.toStringAsFixed(2)} ₪',
                            style: const TextStyle(
                              color: Color(0xFFD94C4C),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF9AA3AF),
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================
  // Payments
  // =========================================================

  Widget _buildPayments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('debtPayments')
          .where('customerId', isEqualTo: widget.customerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _emptyCard('تعذر تحميل الدفعات');
        }

        final docs = List<QueryDocumentSnapshot>.from(
          snapshot.data?.docs ?? [],
        );

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) {
            return 0;
          }

          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return _emptyCard('لا توجد دفعات حتى الآن');
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final double amount = ((data['amount'] ?? 0) as num).toDouble();

            final Timestamp? createdAt = data['createdAt'] as Timestamp?;

            final String date = _formatTimestamp(createdAt);

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
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: Colors.green,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'دفعة',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Color(0xFF8B95A3),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    '- ${amount.toStringAsFixed(2)} ₪',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================
  // Payment Button
  // =========================================================

  Widget _buildPaymentButton({
    required double currentDebt,
    required String customerName,
    required bool hasPendingDebt,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPendingDebt) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.sync_problem_rounded,
                      color: Color(0xFFE09B00),
                      size: 20,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'لا يمكن تسجيل دفعة الآن. يوجد بيع دين بانتظار المزامنة.',
                        style: TextStyle(color: navy, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: hasPendingDebt
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddDebtPaymentScreen(
                              customerId: widget.customerId,
                              customerName: customerName,
                              currentDebt: currentDebt,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD7DBE2),
                  disabledForegroundColor: const Color(0xFF8A94A3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                  hasPendingDebt ? 'بانتظار المزامنة' : 'تسجيل دفعة',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // Helpers
  // =========================================================

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF8A94A3), fontSize: 13),
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
