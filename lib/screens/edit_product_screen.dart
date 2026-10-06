import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> initialData;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.initialData,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  late final TextEditingController nameController;
  late final TextEditingController categoryController;
  late final TextEditingController salePriceController;
  late final TextEditingController lowStockLimitController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: (widget.initialData['name'] ?? '').toString(),
    );

    categoryController = TextEditingController(
      text: (widget.initialData['category'] ?? '').toString(),
    );

    salePriceController = TextEditingController(
      text: ((widget.initialData['salePrice'] ?? 0) as num)
          .toDouble()
          .toStringAsFixed(2),
    );

    lowStockLimitController = TextEditingController(
      text: ((widget.initialData['lowStockLimit'] ?? 0) as num)
          .toInt()
          .toString(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    salePriceController.dispose();
    lowStockLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final category = categoryController.text.trim();

    final salePrice = double.tryParse(salePriceController.text.trim());

    final lowStockLimit = int.tryParse(lowStockLimitController.text.trim());

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

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
            'name': name,
            'category': category,
            'salePrice': salePrice,
            'lowStockLimit': lowStockLimit,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تعديل المنتج بنجاح')));

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _showMessage('تعذر تعديل المنتج: ${e.code}');
    } catch (_) {
      if (!mounted) return;

      _showMessage('تعذر تعديل المنتج');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
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
            'تعديل المنتج',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: navy,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'اسم المنتج',
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'التصنيف',
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: salePriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: _decoration(
                        label: 'سعر البيع',
                        icon: Icons.sell_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lowStockLimitController,
                      keyboardType: TextInputType.number,
                      decoration: _decoration(
                        label: 'حد تنبيه المخزون',
                        icon: Icons.warning_amber_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFFE09B00)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'كمية المخزون لا تُعدّل من هنا. '
                        'تتغير من إضافة البضاعة أو البيع.',
                        style: TextStyle(color: navy, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'حفظ التعديلات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: navy),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
