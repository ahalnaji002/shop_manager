import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'sale_details_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color background = Color(0xFFF6F7F9);

  String filter = 'all';

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
            'سجل المبيعات',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sales').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('تعذر تحميل سجل المبيعات'));
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

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final paymentType = data['paymentType'] ?? 'cash';

              if (filter == 'cash') {
                return paymentType == 'cash';
              }

              if (filter == 'debt') {
                return paymentType == 'debt';
              }

              return true;
            }).toList();

            double totalSales = 0;
            for (final doc in filteredDocs) {
              final data = doc.data() as Map<String, dynamic>;

              final status = data['status'] ?? 'active';

              if (status == 'cancelled') {
                continue;
              }

              totalSales += ((data['totalAmount'] ?? 0) as num).toDouble();
            }

            return Column(
              children: [
                _buildHeader(
                  count: filteredDocs.length,
                  totalSales: totalSales,
                ),

                _buildFilters(),

                Expanded(
                  child: filteredDocs.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد مبيعات',
                            style: TextStyle(
                              color: Color(0xFF7C8796),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];

                            final data = doc.data() as Map<String, dynamic>;

                            return _buildSaleCard(saleId: doc.id, data: data);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({required int count, required double totalSales}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCard(title: 'عدد الفواتير', value: '$count'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              title: 'إجمالي المبيعات',
              value: '${totalSales.toStringAsFixed(2)} ₪',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(color: Color(0xFFB8C4D4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _filterButton(title: 'الكل', value: 'all'),
          const SizedBox(width: 8),
          _filterButton(title: 'نقدي', value: 'cash'),
          const SizedBox(width: 8),
          _filterButton(title: 'دين', value: 'debt'),
        ],
      ),
    );
  }

  Widget _filterButton({required String title, required String value}) {
    final selected = filter == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            filter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? navy : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? navy : const Color(0xFFE7EAF0),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaleCard({
    required String saleId,
    required Map<String, dynamic> data,
  }) {
    final paymentType = data['paymentType'] ?? 'cash';

    final totalAmount = ((data['totalAmount'] ?? 0) as num).toDouble();

    final customerName = data['customerName'] ?? '';

    final createdAt = data['createdAt'] as Timestamp?;

    final isDebt = paymentType == 'debt';

    final status = data['status'] ?? 'active';
    final isCancelled = status == 'cancelled';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleDetailsScreen(saleId: saleId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDebt
                      ? const Color(0xFFFFF1F1)
                      : const Color(0xFFEFF8F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDebt ? Icons.schedule_rounded : Icons.payments_outlined,
                  color: isDebt ? const Color(0xFFD94C4C) : Colors.green,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isDebt ? 'بيع بالدين' : 'بيع نقدي',
                            style: TextStyle(
                              color: isCancelled
                                  ? const Color(0xFF9AA3AF)
                                  : navy,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        if (isCancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              'ملغاة',
                              style: TextStyle(
                                color: Color(0xFFD94C4C),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    if (isDebt && customerName.toString().isNotEmpty)
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: Color(0xFF7C8796),
                          fontSize: 12,
                        ),
                      ),

                    if (isDebt && customerName.toString().isNotEmpty)
                      const SizedBox(height: 3),

                    Text(
                      _formatTimestamp(createdAt),
                      style: const TextStyle(
                        color: Color(0xFF9AA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${totalAmount.toStringAsFixed(2)} ₪',
                    style: TextStyle(
                      color: isCancelled ? const Color(0xFF9AA3AF) : navy,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 5),
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
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'الآن';
    }

    final date = timestamp.toDate();

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} - $hour:$minute';
  }
}
