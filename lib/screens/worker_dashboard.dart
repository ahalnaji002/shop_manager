import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'products_screen.dart';
import 'new_sale_screen.dart';
import 'customers_screen.dart';
import 'sales_history_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../local/app_database.dart';
import '../services/sale_service.dart';

class WorkerDashboard extends StatelessWidget {
  final SaleService saleService;
  final AppDatabase database;

  const WorkerDashboard({
    super.key,
    required this.saleService,
    required this.database,
  });

  static const Color navy = Color(0xFF0B1F3A);
  static const Color darkNavy = Color(0xFF061325);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                _buildHeader(),

                const SizedBox(height: 16),

                _buildTodaySummary(),

                const SizedBox(height: 14),

                _buildPendingSyncCard(),

                const SizedBox(height: 24),

                _buildActions(),

                const SizedBox(height: 24),

                _buildLowStockSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, darkNavy],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: navy,
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دكان أبو هاشم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'واجهة العامل',
                      style: TextStyle(color: Color(0xFFB8C4D4), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
              ),

              IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'أهلًا محمد 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'جاهز نرتب شغل اليوم؟',
            style: TextStyle(color: Color(0xFFB8C4D4), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary() {
    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day);

    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .where(
        'createdAt',
        isGreaterThanOrEqualTo:
        Timestamp.fromDate(startOfDay),
      )
          .where(
        'createdAt',
        isLessThan:
        Timestamp.fromDate(endOfDay),
      )
          .snapshots(),
      builder: (context, salesSnapshot) {
        double todaySales = 0;

        if (salesSnapshot.hasData) {
          for (final doc in salesSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final status = data['status'] ?? 'active';

            if (status == 'cancelled') {
              continue;
            }

            todaySales += ((data['totalAmount'] ?? 0) as num).toDouble();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('debtPayments')
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
              .snapshots(),
          builder: (context, paymentsSnapshot) {
            double todayDebtPayments = 0;

            if (paymentsSnapshot.hasData) {
              for (final doc in paymentsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;

                todayDebtPayments += ((data['amount'] ?? 0) as num).toDouble();
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملخص اليوم',
                    style: TextStyle(
                      color: navy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          title: 'مبيعات اليوم',
                          value: '${todaySales.toStringAsFixed(2)} ₪',
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _summaryCard(
                          title: 'تحصيلات الديون',
                          value: '${todayDebtPayments.toStringAsFixed(2)} ₪',
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: navy, size: 21),
          ),
          const SizedBox(height: 11),
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF7C8796), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final actions = [
      ('بيع جديد', Icons.shopping_cart_checkout_rounded),
      ('الديون', Icons.people_alt_outlined),
      ('المنتجات', Icons.inventory_2_outlined),
      ('سجل المبيعات', Icons.receipt_long_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'العمليات',
            style: TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (action.$1 == 'سجل المبيعات') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesHistoryScreen(),
                      ),
                    );
                  }

                  if (action.$1 == 'الديون') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomersScreen(
                              database: database,
                            ),
                      ),
                    );
                  }

                  if (action.$1 == 'بيع جديد') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewSaleScreen(saleService: saleService),
                      ),
                    );
                  }

                  if (action.$1 == 'المنتجات') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductsScreen()),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(action.$2, color: navy),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        action.$1,
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text('تعذر تحميل تنبيهات المخزون'),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final lowStockProducts = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final stock = ((data['currentStock'] ?? 0) as num).toInt();

          final limit = ((data['lowStockLimit'] ?? 0) as num).toInt();

          return stock <= limit;
        }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFFFF4DA),
                  child: Icon(
                    Icons.inventory_outlined,
                    color: Color(0xFFE09B00),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تنبيهات المخزون',
                        style: TextStyle(
                          color: navy,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        lowStockProducts.isEmpty
                            ? 'لا توجد منتجات منخفضة المخزون حاليًا'
                            : '${lowStockProducts.length} منتج يحتاج إعادة تعبئة',
                        style: TextStyle(
                          color: lowStockProducts.isEmpty
                              ? const Color(0xFF818B98)
                              : const Color(0xFFE09B00),
                          fontSize: 13,
                          fontWeight: lowStockProducts.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (lowStockProducts.isNotEmpty)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE09B00),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingSyncCard() {
    return StreamBuilder<List<PendingSale>>(
      stream: (database.select(database.pendingSales)
        ..where(
              (tbl) => tbl.status.equals('pending'),
        ))
          .watch(),
      builder: (context, snapshot) {
        final pendingCount =
            snapshot.data?.length ?? 0;

        final hasPending =
            pendingCount > 0;

        return Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          child: Container(
            padding:
            const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasPending
                  ? const Color(0xFFFFF6E2)
                  : const Color(0xFFEFF8F1),
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color: hasPending
                    ? const Color(0xFFF2D89C)
                    : const Color(0xFFCFE9D5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasPending
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done_outlined,
                  color: hasPending
                      ? const Color(0xFFE09B00)
                      : Colors.green,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPending
                            ? 'مبيعات بانتظار المزامنة'
                            : 'حالة المزامنة',
                        style:
                        const TextStyle(
                          color: navy,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        hasPending
                            ? '$pendingCount عملية محفوظة على الجهاز'
                            : 'كل المبيعات متزامنة',
                        style:
                        const TextStyle(
                          color:
                          Color(0xFF7C8796),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
