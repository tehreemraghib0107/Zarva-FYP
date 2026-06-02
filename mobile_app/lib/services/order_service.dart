import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class OrderService {
  static const String baseUrl = '${AppConstants.baseUrl}/orders';

  Future<Map<String, dynamic>> placeOrder({
    required List<dynamic> items,
    required double totalAmount,
    required double shippingFee,
    required String orderId,
    required String paymentMethod,
    required String customerName,
    required String customerEmail,
    required String phoneNumber,
    required String shippingAddress,
    String? promoCode,
    double? discountPercent,
    double? discountAmount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return {'success': false, 'message': 'Not logged in'};

      // Normalize cart items to what backend expects.
      // Cart items use `id`, while backend expects `productId`.
      final normalizedItems = items.map((raw) {
        final productId = raw['productId'] ?? raw['id'] ?? raw['_id'];
        return {
          'productId': productId,
          'name': raw['name'],
          'price': raw['price'],
          'quantity': raw['quantity'],
          'size': raw['size'] ?? raw['selectedSize'] ?? '',
          'image': raw['image'],
        };
      }).toList();

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'items': normalizedItems,
          'totalAmount': totalAmount,
          'shippingFee': shippingFee,
          'orderId': orderId,
          'paymentMethod': paymentMethod,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'phoneNumber': phoneNumber,
          'shippingAddress': shippingAddress,
          if (promoCode != null && promoCode.isNotEmpty) 'promoCode': promoCode,
          if (discountPercent != null) 'discountPercent': discountPercent,
          if (discountAmount != null) 'discountAmount': discountAmount,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'order': jsonDecode(response.body)};
      } else {
        try {
          final data = jsonDecode(response.body);
          return {'success': false, 'message': data['msg'] ?? data['error'] ?? 'Failed to place order'};
        } catch (_) {
          final body = response.body;
          final preview = body.length > 200 ? body.substring(0, 200) : body;
          return {
            'success': false,
            'message': 'Failed to place order (HTTP ${response.statusCode}): $preview'
          };
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<List<dynamic>> getOrderHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print("Order History Error: $e");
      return [];
    }
  }
}
