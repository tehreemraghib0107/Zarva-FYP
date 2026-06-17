import 'package:flutter/material.dart';
import '../widgets/custom_scaffold.dart';
import 'online_payment_screen.dart';
import 'checkout_details_screen.dart';

class PaymentMethodScreen extends StatelessWidget {
  final List<dynamic> items;
  final double subtotal;
  final String? promoCode;
  final double discountPercent;
  final double discountAmount;

  const PaymentMethodScreen({
    super.key,
    required this.items,
    required this.subtotal,
    this.promoCode,
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    const double deliveryCharges = 250.0;
    final double total = subtotal + deliveryCharges;

    return CustomScaffold(
      currentIndex: 3,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : zDarkBlue),
            ),
            const SizedBox(height: 30),
            _paymentOption(
              context,
              title: 'Cash on Delivery',
              subtitle: 'Pay when you receive your order',
              icon: Icons.money,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutDetailsScreen(
                      items: items,
                      subtotal: subtotal,
                      deliveryCharges: deliveryCharges,
                      paymentMethod: 'Cash on Delivery',
                      promoCode: promoCode,
                      discountPercent: discountPercent,
                      discountAmount: discountAmount,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _paymentOption(
              context,
              title: 'Online Payment',
              subtitle: 'EasyPaisa, JazzCash, or Card',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OnlinePaymentScreen(
                      items: items,
                      subtotal: subtotal,
                      deliveryCharges: deliveryCharges,
                      promoCode: promoCode,
                      discountPercent: discountPercent,
                      discountAmount: discountAmount,
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _summaryRow('Subtotal', 'PKR ${subtotal.toStringAsFixed(0)}'),
                  const SizedBox(height: 10),
                  _summaryRow('Delivery Charges', 'PKR ${deliveryCharges.toStringAsFixed(0)}'),
                  const Divider(height: 30),
                  _summaryRow('Total', 'PKR ${total.toStringAsFixed(0)}', isBold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0B1C2D).withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFF0B1C2D)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
