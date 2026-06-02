import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ProductService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web, or your machine's IP for physical device
  // Update this to match auth_service.dart if different
  static const String baseUrl = AppConstants.baseUrl;

  // Fetch Products (with optional query)
  Future<List<dynamic>> fetchProducts({String query = '', String category = ''}) async {
    try {
      String url = '$baseUrl/products?';
      if (query.isNotEmpty) url += 'q=$query&';
      if (category.isNotEmpty) url += 'category=$category&';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/$productId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Get Favorites
  Future<List<dynamic>> getFavorites() async {
    final token = await _getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Toggle Favorite
  Future<bool?> toggleFavorite(String productId) async {
    final token = await _getToken();
    if (token == null) return null;

    try {
      // First check if it exists (by trying to add)
      final response = await http.post(
        Uri.parse('$baseUrl/favorites'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'productId': productId}),
      );

      if (response.statusCode == 200) {
        // Added
        return true; 
      } else if (response.statusCode == 400 && response.body.contains("already")) {
        // Already exists, so remove it
        final delResponse = await http.delete(
          Uri.parse('$baseUrl/favorites/$productId'),
          headers: {
             'Content-Type': 'application/json',
             'x-auth-token': token,
          },
        );
        return delResponse.statusCode == 200 ? false : null; // False means removed
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
