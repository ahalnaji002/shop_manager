import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/cloud_function_client.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  final quantityController = TextEditingController();
  final purchasePriceController = TextEditingController();

  String? selectedProductId;
  bool isSaving = false;
  String? _batchId;

  @override
  void dispose() {
    quantityController.dispose();
    purchasePriceController.dispose();
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
            'إضافة بضاعة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
              return const Center(child: Text('تعذر تحميل المنتجات'));
            }

            final products = snapshot.data?.docs ?? [];

            if (products.isEmpty) {
              return const Center(
                child: Text('لا توجد منتجات لإضافة بضاعة لها'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'بيانات البضاعة',
                    style: TextStyle(
                      color: navy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    initialValue: selectedProductId,
                    decoration: InputDecoration(
                      labelText: 'اختر المنتج',
                      prefixIcon: const Icon(
                        Icons.inventory_2_outlined,
                        color: navy,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: products.map((product) {
                      final data = product.data() as Map<String, dynamic>;

                      return DropdownMenuItem<String>(
                        value: product.id,
                        child: Text(data['name'] ?? 'منتج بدون اسم'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  _field(
                    controller: quantityController,
                    label: 'الكمية',
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 16),

                  _field(
                    controller: purchasePriceController,
                    label: 'سعر شراء القطعة',
                    icon: Icons.payments_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: navy),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سيتم إضافة الكمية إلى المخزون الحالي وتسجيلها كدفعة شراء مستقلة.',
                            style: TextStyle(color: navy, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveStock,
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
                              'إضافة للمخزون',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
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

  Future<void> saveStock() async {
    if (selectedProductId == null) {
      _showMessage('اختر المنتج');
      return;
    }
    final quantity = int.tryParse(quantityController.text.trim());
    final purchasePrice = double.tryParse(purchasePriceController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showMessage('أدخل كمية صحيحة');
      return;
    }
    if (purchasePrice == null || purchasePrice <= 0) {
      _showMessage('أدخل سعر شراء صحيح');
      return;
    }

    setState(() => isSaving = true);
    try {
      _batchId ??= FirebaseFirestore.instance
          .collection('purchase_batches')
          .doc()
          .id;
      await CloudFunctionClient.call('addStock', {
        'batchId': _batchId,
        'productId': selectedProductId,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة البضاعة للمخزون')),
      );
      Navigator.pop(context);
    } on CloudFunctionException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('تعذر إضافة البضاعة');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
