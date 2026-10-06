import 'package:flutter/material.dart';

import 'add_product_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController searchController = TextEditingController();

  String searchText = '';

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
          elevation: 0,
          title: const Text(
            'المنتجات والمخزون',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButton: FutureBuilder<bool>(
          future: _isOwnerFuture,
          builder: (context, snapshot) {
            if (snapshot.data != true) {
              return const SizedBox.shrink();
            }

            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );
              },
              backgroundColor: gold,
              foregroundColor: navy,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'إضافة منتج',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('حدث خطأ أثناء تحميل المنتجات'));
            }

            final docs = snapshot.data?.docs ?? [];

            final totalProducts = docs.length;

            final lowStockCount = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final stock = data['currentStock'] ?? 0;
              final limit = data['lowStockLimit'] ?? 0;

              return stock <= limit;
            }).length;

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final name = (data['name'] ?? '').toString().toLowerCase();

              final category = (data['category'] ?? '')
                  .toString()
                  .toLowerCase();

              return name.contains(searchText) || category.contains(searchText);
            }).toList();

            return Column(
              children: [
                _buildTopSection(
                  totalProducts: totalProducts,
                  lowStockCount: lowStockCount,
                ),

                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد منتجات حتى الآن',
                            style: TextStyle(
                              color: Color(0xFF7C8796),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : filteredDocs.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد نتائج للبحث',
                            style: TextStyle(
                              color: Color(0xFF7C8796),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filteredDocs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final data =
                                filteredDocs[index].data()
                                    as Map<String, dynamic>;

                            final name = data['name'] ?? '';
                            final category = data['category'] ?? '';

                            final salePrice = (data['salePrice'] ?? 0)
                                .toDouble();

                            final stock = data['currentStock'] ?? 0;

                            final limit = data['lowStockLimit'] ?? 0;

                            return _buildProductCard(
                              productId: filteredDocs[index].id,
                              data: data,
                              name: name,
                              category: category,
                              price: '${salePrice.toStringAsFixed(2)} ₪',
                              stock: stock,
                              limit: limit,
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

  Widget _buildTopSection({
    required int totalProducts,
    required int lowStockCount,
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
              hintText: 'ابحث عن منتج...',
              hintStyle: const TextStyle(color: Color(0xFF8E98A7)),
              prefixIcon: const Icon(Icons.search_rounded, color: navy),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                child: _StatChip(
                  title: 'عدد المنتجات',
                  value: '$totalProducts',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StatChip(title: 'مخزون منخفض', value: '$lowStockCount'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String productId,
    required Map<String, dynamic> data,
    required String name,
    required String category,
    required String price,
    required int stock,
    required int limit,
  }) {
    final bool isLowStock = stock <= limit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowStock ? const Color(0xFFFFD88A) : const Color(0xFFEEF0F3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: navy,
              size: 28,
            ),
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
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFF8B95A3),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'المخزون: $stock',
                      style: TextStyle(
                        color: isLowStock
                            ? const Color(0xFFE09B00)
                            : const Color(0xFF667085),
                        fontSize: 13,
                        fontWeight: isLowStock
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FutureBuilder<bool>(
            future: _isOwnerFuture,
            builder: (context, snapshot) {
              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }

              return PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF7C8796),
                ),
                onSelected: (value) {
                  if (value == 'details') {
                    _showProductDetails(
                      name: name,
                      category: category,
                      salePrice: ((data['salePrice'] ?? 0) as num).toDouble(),
                      stock: stock,
                      limit: limit,
                    );
                  }

                  if (value == 'edit') {
                    _showEditProductDialog(productId: productId, data: data);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'details', child: Text('التفاصيل')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDetails({
    required String name,
    required String category,
    required double salePrice,
    required int stock,
    required int limit,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isLowStock = stock <= limit;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              name,
              style: const TextStyle(color: navy, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  'التصنيف',
                  category.trim().isEmpty ? 'غير محدد' : category,
                ),
                const Divider(),
                _detailRow('سعر البيع', '${salePrice.toStringAsFixed(2)} ₪'),
                const Divider(),
                _detailRow('المخزون الحالي', '$stock'),
                const Divider(),
                _detailRow('حد تنبيه المخزون', '$limit'),
                if (isLowStock) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE09B00),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'هذا المنتج منخفض المخزون',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String title, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(color: Color(0xFF7C8796))),
        ),
        Text(
          value,
          style: const TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _showEditProductDialog({
    required String productId,
    required Map<String, dynamic> data,
  }) async {
    final nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final categoryController = TextEditingController(
      text: (data['category'] ?? '').toString(),
    );
    final salePriceController = TextEditingController(
      text: ((data['salePrice'] ?? 0) as num).toDouble().toStringAsFixed(2),
    );
    final lowStockLimitController = TextEditingController(
      text: ((data['lowStockLimit'] ?? 0) as num).toInt().toString(),
    );

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                title: const Text(
                  'تعديل المنتج',
                  style: TextStyle(color: navy, fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: _editDecoration(
                          'اسم المنتج',
                          Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: categoryController,
                        decoration: _editDecoration(
                          'التصنيف',
                          Icons.category_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: salePriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _editDecoration(
                          'سعر البيع',
                          Icons.sell_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: lowStockLimitController,
                        keyboardType: TextInputType.number,
                        decoration: _editDecoration(
                          'حد تنبيه المخزون',
                          Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'كمية المخزون تعدّل من إضافة البضاعة أو عمليات البيع.',
                        style: TextStyle(
                          color: Color(0xFF8A94A3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final category = categoryController.text.trim();
                            final salePrice = double.tryParse(
                              salePriceController.text.trim(),
                            );
                            final lowStockLimit = int.tryParse(
                              lowStockLimitController.text.trim(),
                            );

                            if (name.isEmpty) {
                              _showMessage('أدخل اسم المنتج');
                              return;
                            }

                            if (salePrice == null || salePrice < 0) {
                              _showMessage('أدخل سعر بيع صحيح');
                              return;
                            }

                            if (lowStockLimit == null || lowStockLimit < 0) {
                              _showMessage('أدخل حد مخزون صحيح');
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            try {
                              await FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(productId)
                                  .update({
                                    'name': name,
                                    'category': category,
                                    'salePrice': salePrice,
                                    'lowStockLimit': lowStockLimit,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              if (mounted) {
                                _showMessage('تم تعديل المنتج بنجاح');
                              }
                            } on FirebaseException catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  isSaving = false;
                                });
                              }

                              if (mounted) {
                                _showMessage('تعذر تعديل المنتج: ${e.code}');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    salePriceController.dispose();
    lowStockLimitController.dispose();
  }

  InputDecoration _editDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: navy),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatChip extends StatelessWidget {
  final String title;
  final String value;

  const _StatChip({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
}
