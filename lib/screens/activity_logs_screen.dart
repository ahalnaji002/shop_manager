import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() =>
      _ActivityLogsScreenState();
}

class _ActivityLogsScreenState
    extends State<ActivityLogsScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
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
          title: const Text(
            'سجل النشاطات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('activityLogs')
              .orderBy(
            'createdAt',
            descending: true,
          )
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
                  'تعذر تحميل سجل النشاطات',
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

              final type =
              (data['type'] ?? '')
                  .toString();

              if (filter == 'sales') {
                return type == 'sale_created' ||
                    type == 'sale_cancelled';
              }

              if (filter == 'payments') {
                return type ==
                    'debt_payment_created';
              }

              return true;
            }).toList();

            return Column(
              children: [
                _buildFilters(),

                Expanded(
                  child: filteredDocs.isEmpty
                      ? const Center(
                    child: Text(
                      'لا توجد نشاطات',
                      style: TextStyle(
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
                      12,
                      16,
                      30,
                    ),
                    itemCount:
                    filteredDocs
                        .length,
                    separatorBuilder:
                        (context, index) =>
                    const SizedBox(
                      height: 10,
                    ),
                    itemBuilder:
                        (context, index) {
                      final doc =
                      filteredDocs[
                      index];

                      final data =
                      doc.data()
                      as Map<
                          String,
                          dynamic>;

                      return _buildActivityCard(
                        data,
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

  Widget _buildFilters() {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        4,
      ),
      child: Row(
        children: [
          _filterButton(
            title: 'الكل',
            value: 'all',
          ),
          const SizedBox(width: 8),
          _filterButton(
            title: 'المبيعات',
            value: 'sales',
          ),
          const SizedBox(width: 8),
          _filterButton(
            title: 'الدفعات',
            value: 'payments',
          ),
        ],
      ),
    );
  }

  Widget _filterButton({
    required String title,
    required String value,
  }) {
    final selected =
        filter == value;

    return Expanded(
      child: InkWell(
        borderRadius:
        BorderRadius.circular(14),
        onTap: () {
          setState(() {
            filter = value;
          });
        },
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: selected
                ? navy
                : Colors.white,
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? navy
                  : const Color(
                0xFFE7EAF0,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : navy,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(
      Map<String, dynamic> data,
      ) {
    final type =
    (data['type'] ?? '')
        .toString();

    final description =
    (data['description'] ?? '')
        .toString();

    final userName =
    (data['userName'] ??
        'غير معروف')
        .toString();

    final timestamp =
    data['createdAt']
    as Timestamp?;

    final isCancelled =
        type == 'sale_cancelled';

    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: isCancelled
              ? const Color(
            0xFFF3CCCC,
          )
              : const Color(
            0xFFEEF0F3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCancelled
                  ? const Color(
                0xFFFFF1F1,
              )
                  : gold.withValues(
                alpha: 0.15,
              ),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              _iconForType(type),
              color: isCancelled
                  ? const Color(
                0xFFD94C4C,
              )
                  : navy,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style:
                  const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF596574,
                    ),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _formatTimestamp(
                    timestamp,
                  ),
                  style:
                  const TextStyle(
                    color:
                    Color(
                      0xFF9AA3AE,
                    ),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(
      String type,
      ) {
    switch (type) {
      case 'sale_created':
        return Icons
            .shopping_cart_outlined;

      case 'sale_cancelled':
        return Icons
            .cancel_outlined;

      case 'debt_payment_created':
        return Icons
            .payments_outlined;

      default:
        return Icons
            .history_rounded;
    }
  }

  String _formatTimestamp(
      Timestamp? timestamp,
      ) {
    if (timestamp == null) {
      return 'الآن';
    }

    final date =
    timestamp.toDate();

    final day =
    date.day
        .toString()
        .padLeft(2, '0');

    final month =
    date.month
        .toString()
        .padLeft(2, '0');

    final hour =
    date.hour
        .toString()
        .padLeft(2, '0');

    final minute =
    date.minute
        .toString()
        .padLeft(2, '0');

    return '$day/$month/${date.year} - '
        '$hour:$minute';
  }
}