import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class PaymentService {
  static const String baseUrl = '${AppConstants.baseUrl}/payments';

  Future<Map<String, dynamic>> initiatePayment({
    required String orderDbId,
    required String provider, // EasyPaisa / JazzCash
    required String phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    final response = await http.post(
      Uri.parse('$baseUrl/initiate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'orderDbId': orderDbId,
        'provider': provider,
        'phoneNumber': phoneNumber,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'data': data};
    }

    try {
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['msg'] ?? 'Failed to initiate payment'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Failed to initiate payment (HTTP ${response.statusCode})',
      };
    }
  }

  Future<Map<String, dynamic>> confirmMockPayment({
    required String orderDbId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    final response = await http.post(
      Uri.parse('$baseUrl/mock/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'orderDbId': orderDbId}),
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }

    try {
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['msg'] ?? 'Mock confirm failed'};
    } catch (_) {
      return {'success': false, 'message': 'Mock confirm failed (HTTP ${response.statusCode})'};
    }
  }
}

