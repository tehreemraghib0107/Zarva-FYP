import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ReviewService {
  static const String baseUrl = '${AppConstants.baseUrl}/reviews';

  Future<List<dynamic>> getProductReviews(String productId) async {
    final res = await http.get(Uri.parse('$baseUrl/product/$productId'));
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>> submitReview({
    required String productId,
    int? rating,
    String? comment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return {'success': false, 'message': 'Not logged in'};

    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'productId': productId,
        if (rating != null) 'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );

    if (res.statusCode == 201) return {'success': true, 'data': jsonDecode(res.body)};
    try {
      final data = jsonDecode(res.body);
      return {'success': false, 'message': data['msg'] ?? 'Failed to submit review'};
    } catch (_) {
      return {'success': false, 'message': 'Failed to submit review'};
    }
  }
}

