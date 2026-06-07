import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../services/favorites_state.dart';
import '../utils/product_id_helper.dart';
import '../widgets/custom_scaffold.dart';
import '../constants.dart';
import 'product_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ProductService _productService = ProductService();
  late Future<List<dynamic>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _refreshFavorites();
  }

  void _refreshFavorites() {
    setState(() {
      _favoritesFuture = _productService.getFavorites();
    });
  }

  Future<void> _removeFavorite(String productId) async {
    await _productService.toggleFavorite(productId);
    await FavoritesState().refresh();
    _refreshFavorites();
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);

    return CustomScaffold(
      currentIndex: 1,
      body: FutureBuilder<List<dynamic>>(
        future: _favoritesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No favorites yet!'));
          }

          final favorites = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final product = favorites[index]['productId']; 
              if (product == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsScreen(
                          product: Map<String, dynamic>.from(product),
                        ),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                     (product['image'] ?? '').toString().startsWith('http')
                       ? product['image']
                       : '${AppConstants.baseUrl.replaceAll('/api', '')}/${product['image'] ?? 'assets/new logo.png'}',
                     width: 60, height: 60, fit: BoxFit.cover,
                     errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                    ),
                  ),
                  title: Text(product['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: zDarkBlue)),
                  subtitle: Text(product['price'] ?? '', style: const TextStyle(color: Colors.black54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: zDarkBlue, size: 28), 
                    onPressed: () => _removeFavorite(normalizeProductId(product['_id'] ?? product['id']) ?? ''),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
