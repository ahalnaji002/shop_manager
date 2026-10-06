import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
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
            'المصاريف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
            );
          },
          backgroundColor: gold,
          foregroundColor: navy,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'إضافة مصروف',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('تعذر تحميل المصاريف'));
            }

            final docs = List<QueryDocumentSnapshot>.from(
              snapshot.data?.docs ?? [],
            );

            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime);
            });

            double totalExpenses = 0;

            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;

              totalExpenses += ((data['amount'] ?? 0) as num).toDouble();
            }

            return Column(
              children: [
                _buildHeader(count: docs.length, totalExpenses: totalExpenses),

                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد مصاريف حتى الآن',
                            style: TextStyle(color: Color(0xFF7C8796)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: docs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];

                            final data = doc.data() as Map<String, dynamic>;

                            final title = data['title'] ?? 'مصروف';

                            final amount = ((data['amount'] ?? 0) as num)
                                .toDouble();

                            final note = data['note'] ?? '';

                            final createdAt = data['createdAt'] as Timestamp?;

                            return _buildExpenseCard(
                              expenseId: doc.id,
                              title: title,
                              amount: amount,
                              note: note,
                              createdAt: createdAt,
                            );
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

  Widget _buildHeader({required int count, required double totalExpenses}) {
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
            child: _statCard(title: 'عدد المصاريف', value: '$count'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statCard(
              title: 'إجمالي المصاريف',
              value: '${totalExpenses.toStringAsFixed(2)} ₪',
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

  Widget _buildExpenseCard({
    required String expenseId,
    required String title,
    required double amount,
    required String note,
    required Timestamp? createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFFD94C4C),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFF7C8796),
                      fontSize: 12,
                    ),
                  ),
                ],
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

          Text(
            '- ${amount.toStringAsFixed(2)} ₪',
            style: const TextStyle(
              color: Color(0xFFD94C4C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(width: 6),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF7C8796)),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteExpense(
                  expenseId: expenseId,
                  title: title,
                  amount: amount,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'حذف المصروف',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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

  Future<void> _confirmDeleteExpense({
    required String expenseId,
    required String title,
    required double amount,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف المصروف'),
          content: Text(
            'هل أنت متأكد من حذف "$title" بقيمة '
            '${amount.toStringAsFixed(2)} ₪؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _deleteExpense(expenseId);
  }

  Future<void> _deleteExpense(String expenseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف المصروف')));
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حذف المصروف: ${e.code}')));
    }
  }
}
