import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final salePriceController = TextEditingController();
  final lowStockController = TextEditingController();

  bool isSaving = false;

  Future<void> saveProduct() async {
    final name = nameController.text.trim();
    final category = categoryController.text.trim();
    final salePriceText = salePriceController.text.trim();
    final lowStockText = lowStockController.text.trim();

    if (name.isEmpty || salePriceText.isEmpty || lowStockText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسم المنتج وسعر البيع وحد تنبيه المخزون'),
        ),
      );
      return;
    }

    final salePrice = double.tryParse(salePriceText);
    final lowStockLimit = int.tryParse(lowStockText);

    if (salePrice == null || salePrice <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('سعر البيع غير صحيح')));
      return;
    }

    if (lowStockLimit == null || lowStockLimit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حد تنبيه المخزون غير صحيح')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('products').add({
        'name': name,
        'category': category,
        'salePrice': salePrice,
        'currentStock': 0,
        'lowStockLimit': lowStockLimit,
        'isActive': true,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج بنجاح')));

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حفظ المنتج: ${e.code}')));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    salePriceController.dispose();
    lowStockController.dispose();
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
            'إضافة منتج',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: nameController,
                label: 'اسم المنتج',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 16),

              _field(
                controller: categoryController,
                label: 'التصنيف (اختياري)',
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 16),

              _field(
                controller: salePriceController,
                label: 'سعر البيع',
                icon: Icons.sell_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),

              _field(
                controller: lowStockController,
                label: 'حد تنبيه المخزون',
                icon: Icons.warning_amber_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
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
                          'حفظ المنتج',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'ملاحظة: الكمية وسعر الشراء سيتم تسجيلهما عند إضافة البضاعة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8A94A3), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: navy),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE7EAF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE7EAF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
    );
  }
}
