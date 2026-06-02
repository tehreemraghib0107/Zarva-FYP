import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../widgets/custom_scaffold.dart';

class OrderHistoryProductsScreen extends StatefulWidget {
  const OrderHistoryProductsScreen({super.key});

  @override
  State<OrderHistoryProductsScreen> createState() => _OrderHistoryProductsScreenState();
}

class _OrderHistoryProductsScreenState extends State<OrderHistoryProductsScreen> {
  final OrderService _orderService = OrderService();
  final ProductService _productService = ProductService();
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await _orderService.getOrderHistory();
    final Map<String, Map<String, dynamic>> byProduct = {};
    for (final o in orders) {
      final items = (o['items'] as List?) ?? [];
      for (final it in items) {
        final raw = it['productId'];
        String id = '';
        if (raw is Map) {
          id = (raw['_id'] ?? raw['id'] ?? '').toString();
        } else {
          id = (raw ?? '').toString();
        }
        if (id.isEmpty) continue;
        byProduct[id] = {
          'productId': id,
          'name': it['name'] ?? 'Product',
          'image': it['image'] ?? '',
          'price': it['price'],
          'size': it['size'] ?? '',
        };
      }
    }

    if (!mounted) return;
    setState(() {
      _products = byProduct.values.toList();
      _loading = false;
    });
  }

  Future<void> _orderAgain(Map<String, dynamic> p) async {
    final productId = p['productId']?.toString();
    if (productId == null || productId.isEmpty) return;
    Map<String, dynamic>? full = await _productService.getProductById(productId);
    if (full == null) {
      final all = await _productService.fetchProducts();
      final name = (p['name'] ?? '').toString().trim().toLowerCase();
      for (final row in all) {
        final rowName = (row['name'] ?? '').toString().trim().toLowerCase();
        if (name.isNotEmpty && rowName == name) {
          full = row as Map<String, dynamic>;
          break;
        }
      }
    }
    if (!mounted) return;
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not available')));
      return;
    }
    Navigator.pushNamed(context, '/product_details', arguments: full);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      currentIndex: 4,
      forceShowBack: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('No ordered products found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    final image = (p['image'] ?? '').toString();
                    final url = image.startsWith('http')
                        ? image
                        : AppConstants.baseUrl.replaceAll('/api', '') + '/' + image;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        title: Text((p['name'] ?? 'Product').toString()),
                        subtitle: Text(
                          p['size'] != null && p['size'].toString().isNotEmpty
                              ? 'US Size: ${p['size']}'
                              : 'Previously ordered',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.replay),
                          tooltip: 'Order again',
                          onPressed: () => _orderAgain(p),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
