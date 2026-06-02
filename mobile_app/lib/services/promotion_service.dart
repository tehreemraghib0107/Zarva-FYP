import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class PromotionService {
  static const String baseUrl = '${AppConstants.baseUrl}/promotions';

  Future<List<dynamic>> getActivePromotions() async {
    final res = await http.get(Uri.parse('$baseUrl/active'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>> validateCode(String code) async {
    final res = await http.get(Uri.parse('$baseUrl/validate/${code.trim()}'));
    if (res.statusCode == 200) return {'success': true, 'promo': jsonDecode(res.body)};
    try {
      final data = jsonDecode(res.body);
      return {'success': false, 'message': data['msg'] ?? 'Invalid promo code'};
    } catch (_) {
      return {'success': false, 'message': 'Invalid promo code'};
    }
  }
}

