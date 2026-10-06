import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/sale_service.dart';

class NewSaleScreen extends StatefulWidget {
  final SaleService saleService;

  const NewSaleScreen({super.key, required this.saleService});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color gold = Color(0xFFF4B942);
  static const Color background = Color(0xFFF6F7F9);

  String? selectedProductId;
  String paymentType = 'cash';

  String? selectedCustomerId;
  String? selectedCustomerName;

  final quantityController = TextEditingController();

  final List<Map<String, dynamic>> cart = [];

  bool isCompletingSale = false;

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  double get total {
    double result = 0;

    for (final item in cart) {
      result += item['total'] as double;
    }

    return result;
  }

  Future<void> completeSale() async {
    if (cart.isEmpty) {
      _showMessage('السلة فارغة');
      return;
    }

    if (paymentType == 'debt' && selectedCustomerId == null) {
      _showMessage('اختر العميل');
      return;
    }

    setState(() {
      isCompletingSale = true;
    });

    try {
      final result = await widget.saleService.completeSale(
        cart: cart,
        paymentType: paymentType,
        customerId: selectedCustomerId,
        customerName: selectedCustomerName,
      );

      if (!mounted) return;

      if (result.isSynced) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تسجيل البيع بنجاح')));

        Navigator.pop(context);
        return;
      }

      if (result.isPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يوجد اتصال. تم حفظ البيع على الجهاز وسيتم مزامنته لاحقًا.',
            ),
            duration: Duration(seconds: 4),
          ),
        );

        Navigator.pop(context);
        return;
      }

      _showMessage(result.message ?? 'تعذر إتمام البيع');
    } catch (e) {
      if (!mounted) return;

      _showMessage('حدث خطأ أثناء إتمام البيع');
    } finally {
      if (mounted) {
        setState(() {
          isCompletingSale = false;
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
            'بيع جديد',
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

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProductSelector(products),
                        const SizedBox(height: 18),
                        _buildCart(),
                        const SizedBox(height: 20),
                        _buildPaymentType(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductSelector(List<QueryDocumentSnapshot> products) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إضافة صنف',
            style: TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: selectedProductId,
            decoration: InputDecoration(
              labelText: 'اختر المنتج',
              prefixIcon: const Icon(Icons.inventory_2_outlined, color: navy),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: products.map((product) {
              final data = product.data() as Map<String, dynamic>;

              final name = data['name'] ?? '';
              final stock = data['currentStock'] ?? 0;

              return DropdownMenuItem<String>(
                value: product.id,
                child: Text('$name — متوفر: $stock'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedProductId = value;
              });
            },
          ),

          const SizedBox(height: 14),

          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الكمية',
              prefixIcon: const Icon(Icons.numbers_rounded, color: navy),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                _addToCart(products);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: navy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text(
                'إضافة للسلة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(List<QueryDocumentSnapshot> products) {
    if (selectedProductId == null) {
      _showMessage('اختر المنتج');
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      _showMessage('أدخل كمية صحيحة');
      return;
    }

    final product = products.firstWhere((doc) => doc.id == selectedProductId);

    final data = product.data() as Map<String, dynamic>;

    final name = data['name'] ?? '';
    final stock = (data['currentStock'] ?? 0) as num;
    final salePrice = (data['salePrice'] ?? 0).toDouble();

    if (quantity > stock) {
      _showMessage('الكمية المطلوبة أكبر من المخزون');
      return;
    }

    final existingIndex = cart.indexWhere(
      (item) => item['productId'] == product.id,
    );

    if (existingIndex != -1) {
      final oldQuantity = cart[existingIndex]['quantity'] as int;

      final newQuantity = oldQuantity + quantity;

      if (newQuantity > stock) {
        _showMessage('إجمالي الكمية أكبر من المخزون');
        return;
      }

      setState(() {
        cart[existingIndex]['quantity'] = newQuantity;
        cart[existingIndex]['total'] = newQuantity * salePrice;
      });
    } else {
      setState(() {
        cart.add({
          'productId': product.id,
          'name': name,
          'quantity': quantity,
          'salePrice': salePrice,
          'total': quantity * salePrice,
        });
      });
    }

    quantityController.clear();
    selectedProductId = null;
  }

  Widget _buildCart() {
    if (cart.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xFF9AA3AF),
              size: 42,
            ),
            SizedBox(height: 10),
            Text('السلة فارغة', style: TextStyle(color: Color(0xFF7C8796))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'السلة',
          style: TextStyle(
            color: navy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...cart.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${item['quantity']} × ${item['salePrice'].toStringAsFixed(2)} ₪',
                        style: const TextStyle(
                          color: Color(0xFF7C8796),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item['total'].toStringAsFixed(2)} ₪',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      cart.removeAt(index);
                    });
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentType() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'طريقة الدفع',
              style: TextStyle(
                color: navy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            RadioGroup<String>(
              groupValue: paymentType,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  paymentType = value;

                  if (value == 'cash') {
                    selectedCustomerId = null;
                    selectedCustomerName = null;
                  }
                });
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'cash',
                    activeColor: gold,
                    title: const Text('نقدي'),
                  ),

                  RadioListTile<String>(
                    value: 'debt',
                    activeColor: gold,
                    title: const Text('دين'),
                  ),
                ],
              ),
            ),

            if (paymentType == 'debt') ...[
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('customers')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'تعذر تحميل العملاء',
                      style: TextStyle(color: Colors.redAccent),
                    );
                  }

                  final customers = snapshot.data?.docs ?? [];

                  if (customers.isEmpty) {
                    return const Text(
                      'لا يوجد عملاء. أضف عميلًا أولًا من شاشة الديون.',
                      style: TextStyle(color: Color(0xFF7C8796)),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: selectedCustomerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'اختر العميل',
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: navy,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: customers.map((customer) {
                      final data = customer.data() as Map<String, dynamic>;

                      final name = data['name'] ?? 'بدون اسم';
                      final debt = ((data['currentDebt'] ?? 0) as num)
                          .toDouble();

                      return DropdownMenuItem<String>(
                        value: customer.id,
                        child: Text(
                          '$name — دينه ${debt.toStringAsFixed(2)} ₪',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) {
                        setState(() {
                          selectedCustomerId = null;
                          selectedCustomerName = null;
                        });
                        return;
                      }

                      final customer = customers.firstWhere(
                        (doc) => doc.id == value,
                      );

                      final data = customer.data() as Map<String, dynamic>;

                      setState(() {
                        selectedCustomerId = value;
                        selectedCustomerName = data['name']?.toString();
                      });
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإجمالي',
                    style: TextStyle(color: Color(0xFF7C8796), fontSize: 12),
                  ),
                  Text(
                    '${total.toStringAsFixed(2)} ₪',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: cart.isEmpty || isCompletingSale
                    ? null
                    : completeSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isCompletingSale
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إتمام البيع',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
