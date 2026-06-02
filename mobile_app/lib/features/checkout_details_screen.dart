import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/custom_scaffold.dart';
import '../services/order_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';

class CheckoutDetailsScreen extends StatefulWidget {
  final List<dynamic> items;
  final double subtotal;
  final double deliveryCharges;
  final String paymentMethod;
  final String? initialPhoneNumber;
  final String? promoCode;
  final double discountPercent;
  final double discountAmount;

  const CheckoutDetailsScreen({
    super.key,
    required this.items,
    required this.subtotal,
    required this.deliveryCharges,
    required this.paymentMethod,
    this.initialPhoneNumber,
    this.promoCode,
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  @override
  State<CheckoutDetailsScreen> createState() => _CheckoutDetailsScreenState();
}

class _CheckoutDetailsScreenState extends State<CheckoutDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  final String _orderId = 'ZRV-${const Uuid().v4().substring(0, 8).toUpperCase()}';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    if (widget.initialPhoneNumber != null && widget.initialPhoneNumber!.isNotEmpty) {
      _phoneController.text = widget.initialPhoneNumber!;
    }
  }

  Future<void> _loadUserData() async {
    final result = await AuthService().getProfile();
    if (result['success']) {
      setState(() {
        _nameController.text = result['user']['name'] ?? '';
        _emailController.text = result['user']['email'] ?? '';
      });
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    final result = await OrderService().placeOrder(
      items: widget.items,
      totalAmount: widget.subtotal + widget.deliveryCharges,
      shippingFee: widget.deliveryCharges,
      orderId: _orderId,
      paymentMethod: widget.paymentMethod,
      customerName: _nameController.text,
      customerEmail: _emailController.text,
      phoneNumber: _phoneController.text,
      shippingAddress: _addressController.text,
      promoCode: widget.promoCode,
      discountPercent: widget.discountPercent,
      discountAmount: widget.discountAmount,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (result['success']) {
        CartService().clearCart();
        final order = result['order'];
        final isOnline = widget.paymentMethod != 'Cash on Delivery';
        if (isOnline && order != null && order['_id'] != null) {
          await _startOnlinePayment(orderDbId: order['_id'].toString());
        } else {
          _showSuccessDialog();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to place order')));
      }
    }
  }

  Future<void> _startOnlinePayment({required String orderDbId}) async {
    final pm = widget.paymentMethod.toLowerCase();
    final providerLabel = pm.contains('easy') ? 'Easy Paisa' : (pm.contains('jazz') ? 'Jazz Cash' : widget.paymentMethod);
    final res = await PaymentService().initiatePayment(
      orderDbId: orderDbId,
      provider: widget.paymentMethod,
      phoneNumber: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (!res['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to initiate payment')));
      Navigator.pushReplacementNamed(context, '/history');
      return;
    }

    final data = res['data'] as Map<String, dynamic>;
    final url = data['paymentUrl']?.toString();
    final mode = data['mode']?.toString();
    // IMPORTANT (FYP/mock): On Flutter Web, opening external URLs can replace the current tab
    // and the user never sees the "Confirm Payment" dialog. So for mock mode we DO NOT redirect.
    if (mode != 'mock') {
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment URL not available')));
        Navigator.pushReplacementNamed(context, '/history');
        return;
      }

      final uri = Uri.parse(url);
      // On Flutter Web this opens a new tab/window.
      // On Android/iOS it opens the payment app/browser.
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open payment page')));
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Payment initiated'),
          content: Text(
            mode == 'mock'
                ? 'Your payment request has been sent to $providerLabel. Please confirm to complete the transaction and update your order status.'
                : 'Please complete the payment in the opened page/app. Your order will be updated after confirmation.',
          ),
          actions: [
            if (mode == 'mock')
              ElevatedButton(
                onPressed: () async {
                  final confirm = await PaymentService().confirmMockPayment(orderDbId: orderDbId);
                  if (!mounted) return;
                  if (confirm['success']) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful.')));
                    Navigator.pushReplacementNamed(context, '/history');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(confirm['message'] ?? 'Mock confirm failed')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B1C2D)),
                child: const Text('Confirm Payment', style: TextStyle(color: Colors.white)),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/history');
              },
              child: const Text('Go to Orders'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text('Order Placed!'),
          ],
        ),
        content: Text('Your order $_orderId has been placed successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/history');
            },
            child: const Text('View History'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B1C2D)),
            child: const Text('Continue Shopping', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    final double total = widget.subtotal + widget.deliveryCharges;

    return CustomScaffold(
      currentIndex: 3,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ID: $_orderId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              const Text('Shipping Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: zDarkBlue)),
              const SizedBox(height: 20),
              
              _buildField('Full Name', _nameController, Icons.person_outline),
              const SizedBox(height: 15),
              _buildField('Email', _emailController, Icons.email_outlined, isEmail: true),
              const SizedBox(height: 15),
              _buildField('Phone Number', _phoneController, Icons.phone_outlined, isPhone: true),
              const SizedBox(height: 15),
              _buildField('Shipping Address', _addressController, Icons.location_on_outlined, maxLines: 3),
              
              const SizedBox(height: 40),
              const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: zDarkBlue)),
              const SizedBox(height: 15),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ...widget.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${item['name']} x ${item['quantity']}', style: const TextStyle(fontSize: 14))),
                          Text('PKR ${ (double.parse(item['price'].replaceAll('PKR ', '').replaceAll(',', '')) * item['quantity']).toStringAsFixed(0) }'),
                        ],
                      ),
                    )),
                    const Divider(height: 24),
                    _summaryRow('Subtotal', 'PKR ${widget.subtotal.toStringAsFixed(0)}'),
                    if (widget.discountPercent > 0)
                      _summaryRow(
                        'Promo (${widget.promoCode ?? ''} - ${widget.discountPercent.toStringAsFixed(0)}%)',
                        '- PKR ${widget.discountAmount.toStringAsFixed(0)}',
                      ),
                    _summaryRow('Delivery Charges', 'PKR ${widget.deliveryCharges.toStringAsFixed(0)}'),
                    _summaryRow('Payment method', widget.paymentMethod),
                    const Divider(height: 24),
                    _summaryRow('Total Bill', 'PKR ${total.toStringAsFixed(0)}', isBold: true),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handlePlaceOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: zDarkBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Place Order', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isEmail = false, bool isPhone = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (val) {
        if (val == null || val.isEmpty) return 'This field is required';
        if (isEmail && !val.contains('@')) return 'Invalid email';
        if (isPhone && val.length < 10) return 'Invalid phone number';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0B1C2D)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
