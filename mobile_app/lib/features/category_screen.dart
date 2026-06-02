import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../widgets/custom_scaffold.dart';
import '../constants.dart';

class CategoryScreen extends StatefulWidget {
  final String? initialCategory;
  const CategoryScreen({super.key, this.initialCategory});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ProductService _productService = ProductService();
  late Future<List<dynamic>> _productsFuture;
  final TextEditingController _searchController = TextEditingController();
  
  String _activeCategory = 'All';
  Set<String> _favoriteIds = {}; // Local fav state

  final List<String> _categories = ['All', 'Rings', 'Bracelets', 'Chokers', 'Lockets', 'Necklaces', 'Earrings'];

  @override
  void initState() {
    super.initState();
    _refreshFavorites(); // Load favs
    
    Future.microtask(() {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        if (_categories.contains(args)) {
           setState(() {
             _activeCategory = args;
             _fetchProducts();
           });
        } else {
           setState(() {
             _searchController.text = args;
             _fetchProducts(query: args);
           });
        }
      } else if (widget.initialCategory != null) {
         setState(() {
             _activeCategory = widget.initialCategory!;
             _fetchProducts();
         });
      } else {
         _fetchProducts(); 
      }
    });
  }

  Future<void> _refreshFavorites() async {
    final favs = await _productService.getFavorites();
    if (mounted) {
       setState(() {
          _favoriteIds = favs.map((f) => f['productId']['_id'].toString()).toSet();
       });
    }
  }

  void _fetchProducts({String query = ''}) {
    setState(() {
      String catParam = (query.isNotEmpty) ? '' : (_activeCategory == 'All' ? '' : _activeCategory);
      _productsFuture = _productService.fetchProducts(query: query, category: catParam);
    });
  }

  Future<void> _toggleFavorite(String productId) async {
     final wasLiked = _favoriteIds.contains(productId);
     setState(() {
       if (wasLiked) {
         _favoriteIds.remove(productId);
       } else {
         _favoriteIds.add(productId);
       }
     });
     final result = await _productService.toggleFavorite(productId);
     if (!mounted) return;
     if (result == null) {
       setState(() {
         if (wasLiked) {
           _favoriteIds.add(productId);
         } else {
           _favoriteIds.remove(productId);
         }
       });
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Could not update favorites. Please login again.')),
       );
       return;
     }
     await _refreshFavorites();
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    const Color zBgColor = Color(0xFFF8F9FA);

    return CustomScaffold(
      // We'll treat this as a sub-navigation or part of Home. 
      // It doesn't have a direct bottom nav item, so we'll highlight Home (0) 
      // or just use 0 as it's the main browsing experience.
      currentIndex: 0, 
      body: Column(
        children: [
            // Search & Filter Header
            Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                    children: [
                        TextField(
                            controller: _searchController,
                            onSubmitted: (val) {
                                setState(() => _activeCategory = 'All');
                                _fetchProducts(query: val);
                            },
                            decoration: InputDecoration(
                                hintText: 'Search...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: zBgColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                            ),
                        ),
                        const SizedBox(height: 15),
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                                children: _categories.map((cat) {
                                    final bool isActive = _activeCategory == cat;
                                    return Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: ChoiceChip(
                                            label: Text(cat),
                                            selected: isActive,
                                            onSelected: (val) {
                                                if (val) {
                                                    setState(() {
                                                        _activeCategory = cat;
                                                        _searchController.clear(); 
                                                    });
                                                    _fetchProducts();
                                                }
                                            },
                                            selectedColor: zDarkBlue,
                                            labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
                                            backgroundColor: Colors.white,
                                            side: isActive ? BorderSide.none : const BorderSide(color: Colors.grey),
                                        ),
                                    );
                                }).toList(),
                            ),
                        ),
                    ],
                ),
            ),
            
            // Product Grid
            Expanded(
                child: FutureBuilder<List<dynamic>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                             return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                             return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                             return const Center(child: Text('No products found'));
                        }

                        final products = snapshot.data!;

                        return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.7,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                                final product = products[index];
                                final isLiked = _favoriteIds.contains(product['_id']);
                                
                                int remaining = 1;
                                if (product['inventory'] != null) {
                                    remaining = product['inventory']['remaining'] ?? 1;
                                }
                                final bool isOutOfStock = remaining <= 0;

                                return GestureDetector(
                                    onTap: () {
                                        Navigator.pushNamed(context, '/product_details', arguments: product);
                                    },
                                    child: Container(
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
                                        ),
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Expanded(
                                                    child: Stack(
                                                        children: [
                                                            ClipRRect(
                                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                                child: Image.network(
                                                                    product['image'].toString().startsWith('http') 
                                                                      ? product['image'] 
                                                                      : AppConstants.baseUrl.replaceAll('/api', '') + '/' + product['image'].toString(),
                                                                    width: double.infinity,
                                                                    fit: BoxFit.cover,
                                                                    errorBuilder: (_,__,___) => const Icon(Icons.error),
                                                                ),
                                                            ),
                                                            Positioned(
                                                                top: 8, right: 8,
                                                                child: GestureDetector(
                                                                    onTap: () => _toggleFavorite(product['_id']),
                                                                    child: Container(
                                                                        padding: const EdgeInsets.all(6),
                                                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                                                        child: Icon(
                                                                            isLiked ? Icons.favorite : Icons.favorite_border, 
                                                                            size: 18, 
                                                                            color: zDarkBlue
                                                                        ),
                                                                    ),
                                                                ),
                                                            ),
                                                            if (isOutOfStock)
                                                                Positioned(
                                                                    left: 0, top: 10,
                                                                    child: Container(
                                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                        decoration: const BoxDecoration(
                                                                            color: Colors.red,
                                                                            borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
                                                                        ),
                                                                        child: const Text("Out of Stock", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                                                    )
                                                                ),
                                                        ],
                                                    ),
                                                ),
                                                Padding(
                                                    padding: const EdgeInsets.all(10),
                                                    child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                            Text(product['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: zDarkBlue)),
                                                            const SizedBox(height: 4),
                                                            Text(product['price'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                                            const SizedBox(height: 4),
                                                            const Row(
                                                                children: [
                                                                    Icon(Icons.star, size: 14, color: Colors.amber),
                                                                    SizedBox(width: 4),
                                                                    Text('5.0', style: TextStyle(fontSize: 12)),
                                                                ],
                                                            )
                                                        ],
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                );
                            },
                        );
                    },
                ),
            ),
        ],
      ),
    );
  }
}
