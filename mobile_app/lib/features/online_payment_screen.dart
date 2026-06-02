import 'package:flutter/material.dart';
import '../widgets/custom_scaffold.dart';
import 'checkout_details_screen.dart';

class OnlinePaymentScreen extends StatefulWidget {
  final List<dynamic> items;
  final double subtotal;
  final double deliveryCharges;
  final String? promoCode;
  final double discountPercent;
  final double discountAmount;

  const OnlinePaymentScreen({
    super.key,
    required this.items,
    required this.subtotal,
    required this.deliveryCharges,
    this.promoCode,
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  @override
  State<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends State<OnlinePaymentScreen> {
  String _selectedMethod = 'EasyPaisa';
  final TextEditingController _numberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);

    return CustomScaffold(
      currentIndex: 3,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Online Payment',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: zDarkBlue),
            ),
            const SizedBox(height: 30),
            
            Row(
              children: [
                _methodChip('EasyPaisa'),
                const SizedBox(width: 10),
                _methodChip('JazzCash'),
              ],
            ),
            
            const SizedBox(height: 30),
            _buildTextField('Account Number', _numberController, TextInputType.phone, 'Enter 11 digit number'),
            const SizedBox(height: 10),
            Text(
              'You will confirm the payment securely in your EasyPaisa/JazzCash app/USSD prompt.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (_numberController.text.length < 10) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid number')));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckoutDetailsScreen(
                        items: widget.items,
                        subtotal: widget.subtotal,
                        deliveryCharges: widget.deliveryCharges,
                        paymentMethod: _selectedMethod,
                        initialPhoneNumber: _numberController.text.trim(),
                        promoCode: widget.promoCode,
                        discountPercent: widget.discountPercent,
                        discountAmount: widget.discountAmount,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: zDarkBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Process Payment', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodChip(String method) {
    final bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B1C2D) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? const Color(0xFF0B1C2D) : Colors.grey.shade300),
        ),
        child: Text(
          method,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType type, String hint, {bool isObscured = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          obscureText: isObscured,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
