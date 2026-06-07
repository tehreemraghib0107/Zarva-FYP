import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItem {
  final String id;
  final String name;
  final String image;
  final double price;
  final String category;
  final String selectedSize;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    required this.category,
    this.selectedSize = '',
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'price': price,
        'category': category,
        'selectedSize': selectedSize,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'],
        name: json['name'],
        image: json['image'],
        price: json['price'],
        category: json['category'],
        selectedSize: json['selectedSize'] ?? '',
        quantity: json['quantity'],
      );
}

class CartService with ChangeNotifier {
  static final CartService _instance = CartService._internal();

  factory CartService() {
    return _instance;
  }

  CartService._internal() {
    _loadCart();
  }

  List<CartItem> _items = [];
  String _cartKey = 'cart_items_guest';

  List<CartItem> get items => _items;

  Future<void> _refreshCartKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final userEmail = prefs.getString('user_email');
    final suffix = (userId != null && userId.isNotEmpty)
        ? userId
        : (userEmail != null && userEmail.isNotEmpty ? userEmail : 'guest');
    _cartKey = 'cart_items_$suffix';
  }

  Future<bool> _hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final loggedIn = prefs.getBool('isLoggedIn') ?? false;
    return token != null && token.isNotEmpty && loggedIn;
  }

  /// Wipe guest cart storage and in-memory items (call on logout / guest splash).
  Future<void> clearGuestCart() async {
    _items = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_items_guest');
    notifyListeners();
  }

  // Load from SharedPrefs — guests never retain a cart
  Future<void> _loadCart() async {
    if (!await _hasValidSession()) {
      _items = [];
      notifyListeners();
      return;
    }
    await _refreshCartKey();
    final prefs = await SharedPreferences.getInstance();
    final String? cartString = prefs.getString(_cartKey);
    if (cartString != null) {
      final List<dynamic> decoded = jsonDecode(cartString);
      _items = decoded.map((item) => CartItem.fromJson(item)).toList();
      notifyListeners();
    } else {
      _items = [];
      notifyListeners();
    }
  }

  // Save to SharedPrefs
  Future<void> _saveCart() async {
    await _refreshCartKey();
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_cartKey, encoded);
  }

  /// Call this after login/logout to load the correct user's cart.
  Future<void> reloadForCurrentUser() async {
    if (!await _hasValidSession()) {
      _items = [];
      notifyListeners();
      return;
    }
    await _loadCart();
  }

  /// Clears only the current user's cart.
  Future<void> clearCartAsync() async {
    _items.clear();
    await _saveCart();
    notifyListeners();
  }

  Future<bool> addToCart(Map<String, dynamic> product) async {
    await _refreshCartKey();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      return false;
    }

    // Parse price safely
    String priceStr = product['price'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
    double price = double.tryParse(priceStr) ?? 0.0;
    
    final String productId = (product['_id'] ?? product['id']).toString();
    final String selectedSize = (product['selectedSize'] ?? '').toString();

    int index = _items.indexWhere(
      (item) => item.id == productId && item.selectedSize == selectedSize,
    );
    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(
        id: productId,
        name: product['name'],
        image: product['image'],
        price: price,
        category: product['category'] ?? 'Jewelry',
        selectedSize: selectedSize,
      ));
    }
    await _saveCart();
    notifyListeners();
    return true;
  }

  Future<void> removeFromCart(String id, {String selectedSize = ''}) async {
    if (!await _hasValidSession()) return;
    _items.removeWhere((item) => item.id == id && item.selectedSize == selectedSize);
    await _saveCart();
    notifyListeners();
  }

  Future<void> incrementQuantity(String id, {String selectedSize = ''}) async {
    if (!await _hasValidSession()) return;
    int index = _items.indexWhere((item) => item.id == id && item.selectedSize == selectedSize);
    if (index != -1) {
      _items[index].quantity++;
      await _saveCart();
      notifyListeners();
    }
  }

  Future<void> decrementQuantity(String id, {String selectedSize = ''}) async {
    if (!await _hasValidSession()) return;
    int index = _items.indexWhere((item) => item.id == id && item.selectedSize == selectedSize);
    if (index != -1) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      await _saveCart();
      notifyListeners();
    }
  }

  double get subTotal {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get shipping => _items.isEmpty ? 0.0 : 200.0; 

  double get total => subTotal + shipping;

  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }
}
