import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'product_service.dart';

class WishlistService with ChangeNotifier {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final ProductService _productService = ProductService();
  String _wishlistKey = 'wishlist_items_guest';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _refreshKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userEmail = prefs.getString('user_email');
    final suffix = (userId != null && userId.isNotEmpty)
        ? userId
        : (userEmail != null && userEmail.isNotEmpty ? userEmail : 'guest');
    _wishlistKey = 'wishlist_items_$suffix';
  }

  Future<List<String>> _loadIds() async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      final remote = await _loadRemoteIds(token);
      if (remote != null) return remote;
    }

    await _refreshKey();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wishlistKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _saveIds(List<String> ids) async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      return;
    }

    await _refreshKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wishlistKey, jsonEncode(ids));
    notifyListeners();
  }

  Future<List<String>?> _loadRemoteIds(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/wishlist'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
      );

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! List) return [];

      return body
          .map((row) {
            final dynamic product = row['productId'];
            if (product is Map && product['_id'] != null) {
              return product['_id'].toString();
            }
            if (row['_id'] != null) {
              return row['_id'].toString();
            }
            if (product != null && product.toString().isNotEmpty) {
              return product.toString();
            }
            return '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _toggleRemote(String token, String productId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/wishlist'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token,
        },
        body: jsonEncode({'productId': productId}),
      );

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }

      if (response.statusCode == 400 && response.body.contains('already')) {
        final delResponse = await http.delete(
          Uri.parse('${AppConstants.baseUrl}/wishlist/$productId'),
          headers: {
            'Content-Type': 'application/json',
            'x-auth-token': token,
          },
        );
        if (delResponse.statusCode == 200) {
          notifyListeners();
          return false;
        }
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isInWishlist(String productId) async {
    final ids = await _loadIds();
    return ids.contains(productId);
  }

  Future<bool?> toggle(String productId) async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      final remoteResult = await _toggleRemote(token, productId);
      if (remoteResult != null) return remoteResult;
      // Fallback to local list when remote request fails (e.g. token/session issues).
      // This prevents user-visible dead actions for wishlist.
    }

    final ids = await _loadIds();
    final exists = ids.contains(productId);
    if (exists) {
      ids.remove(productId);
      await _saveIds(ids);
      return false;
    }
    ids.add(productId);
    await _saveIds(ids);
    return true;
  }

  Future<bool> remove(String productId) async {
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final response = await http.delete(
          Uri.parse('${AppConstants.baseUrl}/wishlist/$productId'),
          headers: {
            'Content-Type': 'application/json',
            'x-auth-token': token,
          },
        );
        if (response.statusCode == 200) {
          notifyListeners();
          return true;
        }
      } catch (_) {
        // Fall back to local storage below.
      }
    }

    final ids = await _loadIds();
    final existed = ids.remove(productId);
    if (existed) {
      await _saveIds(ids);
    }
    return existed;
  }

  // Keep wishlist only for currently out-of-stock products.
  // Restocked products are auto-removed.
  Future<List<Map<String, dynamic>>> getOutOfStockWishlistProducts() async {
    final ids = await _loadIds();
    final kept = <String>[];
    final products = <Map<String, dynamic>>[];

    for (final id in ids) {
      final product = await _productService.getProductById(id);
      if (product == null) continue;
      final remainingRaw = ((product['inventory'] ?? const {})['remaining'] ?? 0);
      final remaining = remainingRaw is num ? remainingRaw.toInt() : int.tryParse('$remainingRaw') ?? 0;
      if (remaining <= 0) {
        kept.add(id);
        products.add(product);
      }
    }

    if (kept.length != ids.length) {
      await _saveIds(kept);
    }
    return products;
  }
}
