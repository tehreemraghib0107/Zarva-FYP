import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service to fetch 3D AR models for products from the backend API.
class ArProductModelService {
  static const String _baseUrl = 'http://localhost:3000/api/products';

  /// Fetch 3D model URLs for a specific product by ID
  /// Returns a map with earringsModelUrl, necklaceModelUrl, and genericModelUrl
  static Future<Map<String, String?>> fetchProductArModels(
      String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$productId/ar-models'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch AR models: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return {
        'earringsModelUrl': data['earringsModelUrl'] as String?,
        'necklaceModelUrl': data['necklaceModelUrl'] as String?,
        'genericModelUrl': data['genericModelUrl'] as String?,
      };
    } catch (e) {
      print('Error fetching AR models: $e');
      return {
        'earringsModelUrl': null,
        'necklaceModelUrl': null,
        'genericModelUrl': null,
      };
    }
  }

  /// Fetch a product by ID and return its details with AR models
  static Future<Map<String, dynamic>?> fetchProductWithArModels(
      String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$productId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch product: ${response.statusCode}');
      }

      final product = jsonDecode(response.body) as Map<String, dynamic>;
      final models = await fetchProductArModels(productId);

      return {
        ...product,
        'arModels': models,
      };
    } catch (e) {
      print('Error fetching product with AR models: $e');
      return null;
    }
  }
}
