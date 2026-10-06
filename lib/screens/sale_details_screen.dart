import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/cloud_function_client.dart';

class SaleDetailsScreen extends StatefulWidget {
  final String saleId;

  const SaleDetailsScreen({super.key, required this.saleId});

  @override
  State<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends State<SaleDetailsScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  bool isCancelling = false;

  late final Future<bool> _isOwnerFuture;

  @override
  void initState() {
    super.initState();

    _isOwnerFuture = _checkIfOwner();
  }

  Future<bool> _checkIfOwner() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return false;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return false;
    }

    final data = doc.data();

    return data?['role'] == 'owner' && data?['isActive'] == true;
  }

  Future<String> _getUserName(String? uid) async {
    if (uid == null || uid.trim().isEmpty) {
      return 'غير معروف';
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        return 'غير معروف';
      }

      final data = doc.data();

      final name = (data?['name'] ?? '').toString().trim();

      return name.isEmpty ? 'غير معروف' : name;
    } catch (_) {
      return 'غير معروف';
    }
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
            'تفاصيل الفاتورة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('sales')
              .doc(widget.saleId)
              .snapshots(),
          builder: (context, saleSnapshot) {
            if (saleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (saleSnapshot.hasError ||
                !saleSnapshot.hasData ||
                !saleSnapshot.data!.exists) {
              return const Center(child: Text('تعذر تحميل الفاتورة'));
            }

            final saleData = saleSnapshot.data!.data()!;

            final double totalAmount = ((saleData['totalAmount'] ?? 0) as num)
                .toDouble();

            final String paymentType = saleData['paymentType'] ?? 'cash';

            final String customerName = saleData['customerName'] ?? '';

            final Timestamp? createdAt = saleData['createdAt'] as Timestamp?;

            final String status = saleData['status'] ?? 'active';

            final String? createdBy = saleData['createdBy'] as String?;

            final String? cancelledBy = saleData['cancelledBy'] as String?;

            final double remainingDebt =
                ((saleData['remainingDebt'] ??
                            (paymentType == 'debt' ? totalAmount : 0))
                        as num)
                    .toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == 'cancelled') ...[
                    _buildCancelledBanner(),
                    const SizedBox(height: 14),
                  ],

                  FutureBuilder<bool>(
                    future: _isOwnerFuture,
                    builder: (context, ownerSnapshot) {
                      final isOwner = ownerSnapshot.data == true;
                      if (!isOwner) {
                        return _buildSummaryCard(
                          totalAmount: totalAmount,
                          totalCost: 0,
                          totalProfit: 0,
                          paymentType: paymentType,
                          customerName: customerName,
                          createdAt: createdAt,
                          remainingDebt: remainingDebt,
                          isOwner: false,
                        );
                      }
                      return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        stream: FirebaseFirestore.instance
                            .collection('saleFinancials')
                            .doc(widget.saleId)
                            .snapshots(),
                        builder: (context, financialSnapshot) {
                          final financial = financialSnapshot.data?.data();
                          return _buildSummaryCard(
                            totalAmount: totalAmount,
                            totalCost: ((financial?['totalCost'] ?? 0) as num)
                                .toDouble(),
                            totalProfit:
                                ((financial?['totalProfit'] ?? 0) as num)
                                    .toDouble(),
                            paymentType: paymentType,
                            customerName: customerName,
                            createdAt: createdAt,
                            remainingDebt: remainingDebt,
                            isOwner: true,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  FutureBuilder<String>(
                    future: _getUserName(createdBy),
                    builder: (context, snapshot) {
                      return _buildUserInfoCard(
                        icon: Icons.person_outline_rounded,
                        title: 'تم البيع بواسطة',
                        value: snapshot.data ?? 'جاري التحميل...',
                      );
                    },
                  ),

                  if (status == 'cancelled') ...[
                    const SizedBox(height: 10),

                    FutureBuilder<String>(
                      future: _getUserName(cancelledBy),
                      builder: (context, snapshot) {
                        return _buildUserInfoCard(
                          icon: Icons.cancel_outlined,
                          title: 'تم الإلغاء بواسطة',
                          value: snapshot.data ?? 'جاري التحميل...',
                          danger: true,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  const Text(
                    'الأصناف',
                    style: TextStyle(
                      color: navy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  FutureBuilder<bool>(
                    future: _isOwnerFuture,
                    builder: (context, ownerSnapshot) {
                      return _buildItems(isOwner: ownerSnapshot.data == true);
                    },
                  ),

                  if (status == 'active') ...[
                    const SizedBox(height: 24),

                    FutureBuilder<bool>(
                      future: _isOwnerFuture,
                      builder: (context, ownerSnapshot) {
                        if (ownerSnapshot.data != true) {
                          return const SizedBox.shrink();
                        }

                        return _buildCancelButton(
                          saleData: saleData,
                          totalAmount: totalAmount,
                          remainingDebt: remainingDebt,
                          paymentType: paymentType,
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // Cancelled banner
  // =========================================================

  Widget _buildCancelledBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3CCCC)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: Color(0xFFD94C4C)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'هذه الفاتورة ملغاة وتم عكس أثرها.',
              style: TextStyle(
                color: Color(0xFFD94C4C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Summary
  // =========================================================

  Widget _buildSummaryCard({
    required double totalAmount,
    required double totalCost,
    required double totalProfit,
    required String paymentType,
    required String customerName,
    required Timestamp? createdAt,
    required double remainingDebt,
    required bool isOwner,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: navy),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentType == 'debt' ? 'فاتورة دين' : 'فاتورة نقدية',
                      style: const TextStyle(
                        color: navy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatTimestamp(createdAt),
                      style: const TextStyle(
                        color: Color(0xFF8B95A3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (paymentType == 'debt' && customerName.trim().isNotEmpty) ...[
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: Color(0xFF7C8796),
                ),
                const SizedBox(width: 6),
                Text(
                  customerName,
                  style: const TextStyle(color: Color(0xFF7C8796)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          if (isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: _miniCard(
                    title: 'الإجمالي',
                    value: '${totalAmount.toStringAsFixed(2)} ₪',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniCard(
                    title: 'التكلفة',
                    value: '${totalCost.toStringAsFixed(2)} ₪',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _miniCard(
              title: 'الربح',
              value: '${totalProfit.toStringAsFixed(2)} ₪',
              highlight: true,
            ),
          ] else ...[
            _miniCard(
              title: 'الإجمالي',
              value: '${totalAmount.toStringAsFixed(2)} ₪',
            ),
          ],

          if (paymentType == 'debt') ...[
            const SizedBox(height: 10),

            _miniCard(
              title: 'المتبقي على الفاتورة',
              value: '${remainingDebt.toStringAsFixed(2)} ₪',
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniCard({
    required String title,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFEFF8F1) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF7C8796), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.green : navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool danger = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF1F1) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: danger ? const Color(0xFFF3CCCC) : const Color(0xFFEEF0F3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: danger ? const Color(0xFFD94C4C) : navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7C8796),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: danger ? const Color(0xFFD94C4C) : navy,
                    fontSize: 14,
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
  // Items
  // =========================================================

  Widget _buildItems({required bool isOwner}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sales')
          .doc(widget.saleId)
          .collection('items')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('تعذر تحميل أصناف الفاتورة');
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text(
            'لا توجد أصناف في هذه الفاتورة',
            style: TextStyle(color: Color(0xFF8A94A3)),
          );
        }
        if (!isOwner) return _buildItemCards(docs, null);
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('saleFinancials')
              .doc(widget.saleId)
              .snapshots(),
          builder: (context, financialSnapshot) {
            if (financialSnapshot.hasError) {
              return const Text('تعذر تحميل تفاصيل التكلفة');
            }
            final privateItems =
                financialSnapshot.data?.data()?['items']
                    as Map<String, dynamic>? ??
                <String, dynamic>{};
            return _buildItemCards(docs, privateItems);
          },
        );
      },
    );
  }

  Widget _buildItemCards(
    List<QueryDocumentSnapshot> docs,
    Map<String, dynamic>? privateItems,
  ) {
    return Column(
      children: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final privateData =
            privateItems?[doc.id] as Map<String, dynamic>? ?? {};
        final name = (data['productName'] ?? '').toString();
        final quantity = ((data['quantity'] ?? 0) as num).toInt();
        final unitSalePrice = ((data['unitSalePrice'] ?? 0) as num).toDouble();
        final totalSale = ((data['totalSale'] ?? 0) as num).toDouble();
        final totalCost = ((privateData['totalCost'] ?? 0) as num).toDouble();
        final profit = ((privateData['profit'] ?? 0) as num).toDouble();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEF0F3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '$quantity × ${unitSalePrice.toStringAsFixed(2)} ₪',
                    style: const TextStyle(
                      color: Color(0xFF7C8796),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (privateItems != null)
                Row(
                  children: [
                    Expanded(child: _itemStat('الإجمالي', totalSale)),
                    Expanded(child: _itemStat('التكلفة', totalCost)),
                    Expanded(child: _itemStat('الربح', profit, green: true)),
                  ],
                )
              else
                Row(
                  children: [Expanded(child: _itemStat('الإجمالي', totalSale))],
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _itemStat(String title, double value, {bool green = false}) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFF9AA3AF), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          '${value.toStringAsFixed(2)} ₪',
          style: TextStyle(
            color: green ? Colors.green : navy,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // Cancel button
  // =========================================================

  Widget _buildCancelButton({
    required Map<String, dynamic> saleData,
    required double totalAmount,
    required double remainingDebt,
    required String paymentType,
  }) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: isCancelling
            ? null
            : () {
                _confirmCancelSale(
                  saleData: saleData,
                  totalAmount: totalAmount,
                  remainingDebt: remainingDebt,
                  paymentType: paymentType,
                );
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD94C4C),
          side: const BorderSide(color: Color(0xFFD94C4C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: isCancelling
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.3),
              )
            : const Icon(Icons.cancel_outlined),
        label: Text(
          isCancelling ? 'جاري الإلغاء...' : 'إلغاء الفاتورة',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // =========================================================
  // Confirm cancellation
  // =========================================================

  Future<void> _confirmCancelSale({
    required Map<String, dynamic> saleData,
    required double totalAmount,
    required double remainingDebt,
    required String paymentType,
  }) async {
    if (paymentType == 'debt' && remainingDebt < totalAmount - 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكن إلغاء هذه الفاتورة لأنها تحتوي على دفعات مسددة. '
            'يجب عكس الدفعات أولًا.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('إلغاء الفاتورة'),
          content: const Text(
            'سيتم إرجاع البضاعة إلى المخزون '
            'وعكس أثر الفاتورة. هل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD94C4C),
                foregroundColor: Colors.white,
              ),
              child: const Text('إلغاء الفاتورة'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _cancelSale();
  }

  // =========================================================
  // Cancel sale
  // =========================================================

  Future<void> _cancelSale() async {
    setState(() => isCancelling = true);
    try {
      await CloudFunctionClient.call('cancelSale', {'saleId': widget.saleId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الفاتورة وعكس أثرها بنجاح')),
      );
    } on CloudFunctionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر إلغاء الفاتورة')));
      }
    } finally {
      if (mounted) setState(() => isCancelling = false);
    }
  }

  // Date
  // =========================================================

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
