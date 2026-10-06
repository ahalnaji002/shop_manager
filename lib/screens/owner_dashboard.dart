import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'products_screen.dart';
import 'add_stock_screen.dart';
import 'new_sale_screen.dart';
import 'customers_screen.dart';
import 'sales_history_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'reports_screen.dart';
import 'expenses_screen.dart';
import '../local/app_database.dart';
import '../services/sale_service.dart';
import 'activity_logs_screen.dart';

import 'package:drift/drift.dart' hide Column;

class OwnerDashboard extends StatelessWidget {
  final SaleService saleService;
  final AppDatabase database;

  const OwnerDashboard({
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
                _buildSummary(),
                const SizedBox(height: 14),
                _buildPendingSyncCard(),
                const SizedBox(height: 26),
                _buildQuickActions(),
                const SizedBox(height: 26),
                _buildLowStockSection(),
                const SizedBox(height: 26),
                _buildRecentActivities(),
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
                      'لوحة صاحب الدكان',
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
                  size: 24,
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
            'أهلًا أبو هاشم 👋',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          const Text(
            'هاي نظرة سريعة على وضع الدكان اليوم',
            style: TextStyle(color: Color(0xFFB8C4D4), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day);

    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots(),
      builder: (context, salesSnapshot) {
        if (salesSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final salesDocs = salesSnapshot.data?.docs ?? [];

        double todaySales = 0;
        for (final doc in salesDocs) {
          final data = doc.data() as Map<String, dynamic>;

          final status = data['status'] ?? 'active';

          if (status == 'cancelled') {
            continue;
          }

          todaySales += ((data['totalAmount'] ?? 0) as num).toDouble();
        }

        return FutureBuilder<double>(
          future: _loadTodayProfit(startOfDay, endOfDay),
          builder: (context, profitSnapshot) {
            final todayProfit = profitSnapshot.data ?? 0;
            return StreamBuilder<List<PendingSale>>(
              stream:
                  (database.select(database.pendingSales)..where(
                        (tbl) =>
                            tbl.status.equals('pending') &
                            tbl.paymentType.equals('debt'),
                      ))
                      .watch(),
              builder: (context, pendingDebtSnapshot) {
                final pendingDebtSales = pendingDebtSnapshot.data ?? [];

                double pendingDebtTotal = 0;

                for (final sale in pendingDebtSales) {
                  pendingDebtTotal += sale.totalAmount;
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('customers')
                      .snapshots(),
                  builder: (context, customersSnapshot) {
                    final customerDocs = customersSnapshot.data?.docs ?? [];

                    double totalDebt = 0;

                    for (final doc in customerDocs) {
                      final data = doc.data() as Map<String, dynamic>;

                      totalDebt += ((data['currentDebt'] ?? 0) as num)
                          .toDouble();
                    }

                    totalDebt += pendingDebtTotal;

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('debtPayments')
                          .where(
                            'createdAt',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(
                              startOfDay,
                            ),
                          )
                          .where(
                            'createdAt',
                            isLessThan: Timestamp.fromDate(endOfDay),
                          )
                          .snapshots(),
                      builder: (context, paymentsSnapshot) {
                        final paymentDocs = paymentsSnapshot.data?.docs ?? [];

                        double todayPayments = 0;

                        for (final doc in paymentDocs) {
                          final data = doc.data() as Map<String, dynamic>;

                          todayPayments += ((data['amount'] ?? 0) as num)
                              .toDouble();
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
                                      value:
                                          '${todaySales.toStringAsFixed(2)} ₪',
                                      icon: Icons.shopping_bag_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _summaryCard(
                                      title: 'ربح اليوم',
                                      value:
                                          '${todayProfit.toStringAsFixed(2)} ₪',
                                      icon: Icons.trending_up_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _summaryCard(
                                      title: 'إجمالي الديون',
                                      value:
                                          '${totalDebt.toStringAsFixed(2)} ₪',
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _summaryCard(
                                      title: 'تحصيلات اليوم',
                                      value:
                                          '${todayPayments.toStringAsFixed(2)} ₪',
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
              },
            );
          },
        );
      },
    );
  }

  Future<double> _loadTodayProfit(DateTime start, DateTime end) async {
    final financials = await FirebaseFirestore.instance
        .collection('saleFinancials')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .get();
    return financials.docs.fold<double>(0, (total, document) {
      final data = document.data();
      if ((data['status'] ?? 'active') == 'cancelled') return total;
      return total + ((data['totalProfit'] ?? 0) as num).toDouble();
    });
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

  Widget _buildQuickActions() {
    final actions = [
      ('بيع جديد', Icons.shopping_cart_checkout_rounded),
      ('الديون', Icons.people_alt_outlined),
      ('المنتجات', Icons.inventory_2_outlined),
      ('إضافة بضاعة', Icons.add_box_outlined),
      ('المصاريف', Icons.receipt_long_outlined),
      ('التقارير', Icons.bar_chart_rounded),
      ('سجل المبيعات', Icons.receipt_long_outlined),
      ('سجل النشاطات', Icons.history_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة الدكان',
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
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (action.$1 == 'سجل النشاطات') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivityLogsScreen(),
                      ),
                    );
                  }

                  if (action.$1 == 'سجل المبيعات') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SalesHistoryScreen(),
                      ),
                    );
                  }

                  if (action.$1 == 'المصاريف') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                    );
                  }

                  if (action.$1 == 'التقارير') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsScreen()),
                    );
                  }

                  if (action.$1 == 'الديون') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomersScreen(database: database),
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

                  if (action.$1 == 'إضافة بضاعة') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddStockScreen()),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEEF0F3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(action.$2, color: navy),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        action.$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFF4DA),
                  child: const Icon(
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
      stream: (database.select(
        database.pendingSales,
      )..where((tbl) => tbl.status.equals('pending'))).watch(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.length ?? 0;

        final hasPending = pendingCount > 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasPending
                  ? const Color(0xFFFFF6E2)
                  : const Color(0xFFEFF8F1),
              borderRadius: BorderRadius.circular(18),
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
                  color: hasPending ? const Color(0xFFE09B00) : Colors.green,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPending
                            ? 'مبيعات بانتظار المزامنة'
                            : 'حالة المزامنة',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        hasPending
                            ? '$pendingCount عملية محفوظة على الجهاز'
                            : 'كل المبيعات متزامنة',
                        style: const TextStyle(
                          color: Color(0xFF7C8796),
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

  Widget _buildRecentActivities() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activityLogs')
          .orderBy('createdAt', descending: true)
          .limit(5)
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
            child: Text(
              'تعذر تحميل النشاطات',
              style: TextStyle(color: Color(0xFF7C8796)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'آخر النشاطات',
                style: TextStyle(
                  color: navy,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEEF0F3)),
                ),
                child: docs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'لا توجد نشاطات حتى الآن',
                            style: TextStyle(
                              color: Color(0xFF7C8796),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: List.generate(docs.length, (index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;

                          final userName = (data['userName'] ?? 'غير معروف')
                              .toString();

                          final description = (data['description'] ?? '')
                              .toString();

                          final timestamp = data['createdAt'] as Timestamp?;

                          final type = (data['type'] ?? '').toString();

                          return _activityItem(
                            type: type,
                            userName: userName,
                            description: description,
                            timestamp: timestamp,
                            showDivider: index != docs.length - 1,
                          );
                        }),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _activityItem({
    required String type,
    required String userName,
    required String description,
    required Timestamp? timestamp,
    required bool showDivider,
  }) {
    String timeText = '';

    if (timestamp != null) {
      final date = timestamp.toDate();

      timeText =
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                type == 'sale_cancelled'
                    ? Icons.cancel_outlined
                    : type == 'debt_payment_created'
                    ? Icons.payments_outlined
                    : Icons.shopping_cart_outlined,
                color: type == 'sale_cancelled'
                    ? const Color(0xFFD94C4C)
                    : navy,
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF596574),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            if (timeText.isNotEmpty)
              Text(
                timeText,
                style: const TextStyle(color: Color(0xFF9AA3AE), fontSize: 11),
              ),
          ],
        ),

        if (showDivider) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEF0F3)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
