import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_customer_screen.dart';
import 'customer_details_screen.dart';
import '../local/app_database.dart';
import 'package:drift/drift.dart' hide Column;

class CustomersScreen extends StatefulWidget {
  final AppDatabase database;

  const CustomersScreen({
    super.key,
    required this.database,
  });

  @override
  State<CustomersScreen> createState() =>
      _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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
            'العملاء والديون',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
            );
          },
          backgroundColor: gold,
          foregroundColor: navy,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text(
            'إضافة عميل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<List<PendingSale>>(
          stream: (widget.database.select(
            widget.database.pendingSales,
          )..where(
                (tbl) =>
            tbl.status.equals('pending') &
            tbl.paymentType.equals('debt'),
          ))
              .watch(),
          builder: (context, pendingSnapshot) {
            final pendingSales =
                pendingSnapshot.data ?? [];

            final Map<String, double>
            pendingDebtByCustomer = {};

            for (final sale in pendingSales) {
              final customerId = sale.customerId;

              if (customerId == null) {
                continue;
              }

              pendingDebtByCustomer[customerId] =
                  (pendingDebtByCustomer[customerId] ?? 0) +
                      sale.totalAmount;
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'تعذر تحميل العملاء',
                    ),
                  );
                }

                final docs =
                    snapshot.data?.docs ?? [];

                final filteredDocs =
                docs.where((doc) {
                  final data =
                  doc.data()
                  as Map<String, dynamic>;

                  final name =
                  (data['name'] ?? '')
                      .toString()
                      .toLowerCase();

                  return name.contains(
                    searchText,
                  );
                }).toList();

                double totalDebt = 0;

                for (final doc in docs) {
                  final data =
                  doc.data()
                  as Map<String, dynamic>;

                  final firestoreDebt =
                  ((data['currentDebt'] ?? 0)
                  as num)
                      .toDouble();

                  final pendingDebt =
                      pendingDebtByCustomer[
                      doc.id] ??
                          0;

                  totalDebt +=
                      firestoreDebt +
                          pendingDebt;
                }

                return Column(
                  children: [
                    _buildTopSection(
                      customersCount:
                      docs.length,
                      totalDebt:
                      totalDebt,
                    ),

                    Expanded(
                      child: docs.isEmpty
                          ? const Center(
                        child: Text(
                          'لا يوجد عملاء حتى الآن',
                          style:
                          TextStyle(
                            color: Color(
                              0xFF7C8796,
                            ),
                          ),
                        ),
                      )
                          : filteredDocs.isEmpty
                          ? const Center(
                        child: Text(
                          'لا توجد نتائج للبحث',
                          style:
                          TextStyle(
                            color:
                            Color(
                              0xFF7C8796,
                            ),
                          ),
                        ),
                      )
                          : ListView.separated(
                        padding:
                        const EdgeInsets
                            .fromLTRB(
                          16,
                          10,
                          16,
                          100,
                        ),
                        itemCount:
                        filteredDocs
                            .length,
                        separatorBuilder:
                            (_, _) =>
                        const SizedBox(
                          height: 10,
                        ),
                        itemBuilder:
                            (
                            context,
                            index,
                            ) {
                          final doc =
                          filteredDocs[
                          index];

                          final data =
                          doc.data()
                          as Map<
                              String,
                              dynamic>;

                          final name =
                              data['name'] ??
                                  '';

                          final phone =
                              data['phone'] ??
                                  '';

                          final firestoreDebt =
                          ((data['currentDebt'] ??
                              0)
                          as num)
                              .toDouble();

                          final pendingDebt =
                              pendingDebtByCustomer[
                              doc.id] ??
                                  0;

                          final displayedDebt =
                              firestoreDebt +
                                  pendingDebt;

                          return _buildCustomerCard(
                            customerId:
                            doc.id,
                            name: name,
                            phone: phone,
                            debt:
                            displayedDebt,
                          );
                        },
                      ),
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

  Widget _buildTopSection({
    required int customersCount,
    required double totalDebt,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: const BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) {
              setState(() {
                searchText = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'ابحث عن عميل...',
              prefixIcon: const Icon(Icons.search_rounded, color: navy),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  title: 'عدد العملاء',
                  value: '$customersCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoCard(
                  title: 'إجمالي الديون',
                  value: '${totalDebt.toStringAsFixed(2)} ₪',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
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
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Color(0xFFB8C4D4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard({
    required String customerId,
    required String name,
    required String phone,
    required double debt,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerDetailsScreen(
                customerId: customerId,
                customerName: name,
                phone: phone,
                currentDebt: debt,
                database: widget.database,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: gold.withValues(alpha: 0.16),
                child: const Icon(Icons.person_outline_rounded, color: navy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (phone.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF8B95A3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${debt.toStringAsFixed(2)} ₪',
                    style: TextStyle(
                      color: debt > 0
                          ? Colors.redAccent
                          : const Color(0xFF667085),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'الرصيد',
                    style: TextStyle(color: Color(0xFF9AA3AF), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
