import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/cloud_function_client.dart';

class AddDebtPaymentScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final double currentDebt;

  const AddDebtPaymentScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentDebt,
  });

  @override
  State<AddDebtPaymentScreen> createState() => _AddDebtPaymentScreenState();
}

class _AddDebtPaymentScreenState extends State<AddDebtPaymentScreen> {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController amountController = TextEditingController();

  bool isSaving = false;
  String? _paymentId;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('أدخل مبلغًا صحيحًا');
      return;
    }
    if (amount > widget.currentDebt) {
      _showMessage('المبلغ أكبر من الدين الحالي');
      return;
    }

    setState(() => isSaving = true);
    try {
      _paymentId ??= FirebaseFirestore.instance
          .collection('debtPayments')
          .doc()
          .id;
      await CloudFunctionClient.call('addDebtPayment', {
        'paymentId': _paymentId,
        'customerId': widget.customerId,
        'amount': amount,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة بنجاح')));
      Navigator.pop(context);
    } on CloudFunctionException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('تعذر تسجيل الدفعة');
    } finally {
      if (mounted) setState(() => isSaving = false);
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
            'تسجيل دفعة',
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
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFFFF6E2),
                      child: Icon(Icons.person_outline_rounded, color: navy),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      widget.customerName,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6E2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'الدين الحالي',
                            style: TextStyle(color: Color(0xFF7C8796)),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${widget.currentDebt.toStringAsFixed(2)} ₪',
                            style: const TextStyle(
                              color: Color(0xFFD94C4C),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع',
                  prefixIcon: const Icon(Icons.payments_outlined, color: navy),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _savePayment,
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
                          'حفظ الدفعة',
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
