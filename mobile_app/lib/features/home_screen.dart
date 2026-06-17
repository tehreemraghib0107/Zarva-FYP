import 'dart:async';
import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../config/route_observer.dart';
import '../services/notification_service.dart';
import '../widgets/custom_scaffold.dart';
import '../constants.dart';
import '../utils/auth_helper.dart';
import '../utils/product_id_helper.dart';
import '../services/favorites_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final ProductService _productService = ProductService();
  final NotificationService _notificationService = NotificationService();
  final FavoritesState _favoritesState = FavoritesState();
  // 🔥 Banner controller
  late PageController _pageController;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  final TextEditingController _searchController = TextEditingController();
  
  // 🔍 Data State
  Future<List<dynamic>>? _productsFuture;
  int _unreadNotifications = 0;
  
  // 🔥 Category Data (Matching DB categories)
  final List<Map<String, String>> categories = [
    {'name': 'Rings', 'image': 'assets/1R.png'},
    {'name': 'Bracelets', 'image': 'assets/1B.png'},
    {'name': 'Chokers', 'image': 'assets/1C.png'},
    {'name': 'Lockets', 'image': 'assets/1L.png'},
    {'name': 'Necklaces', 'image': 'assets/2N.png'}, 
    {'name': 'Earrings', 'image': 'assets/1E.png'},
  ];

  // 🔥 Banner Images
  final List<String> bannerImages = [
    'assets/Banner2.png',
    'assets/Banner3.png',
    'assets/Banner4.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startBannerAutoSlide();
    _favoritesState.addListener(_onFavoritesChanged);
    _loadData();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _favoritesState.refresh();
  }

  void _loadData() {
    _productsFuture = _productService.fetchProducts();
    _favoritesState.refresh();
    _refreshUnreadNotifications();
  }

  Future<void> _refreshUnreadNotifications() async {
    final count = await _notificationService.getUnreadCount(limit: 100);
    if (!mounted) return;
    setState(() {
      _unreadNotifications = count;
    });
  }

  void _onSearchSubmitted(String query) {
     Navigator.pushNamed(context, '/category', arguments: query);
  }

  Future<void> _toggleFavorite(dynamic product) async {
     if (!await AuthHelper.requireAuth(context)) return;

     final productId = normalizeProductId(product['_id'] ?? product['id']);
     if (productId == null) return;

     final result = await _favoritesState.toggle(productId);
     if (!mounted) return;
     if (result == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Could not update favorites. Please login again.')),
       );
     }
  }

  void _startBannerAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _currentBannerIndex = (_currentBannerIndex + 1) % bannerImages.length;
        _pageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _favoritesState.removeListener(_onFavoritesChanged);
    _bannerTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);

    return CustomScaffold(
      currentIndex: 0,
      drawer: _buildDrawer(),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/category'),
          icon: const Icon(Icons.search, color: Colors.white),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/notifications');
                await _refreshUnreadNotifications();
              },
              icon: const Icon(Icons.notifications_none, color: Colors.white),
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // 🖼️ BANNER
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 235, 224, 204),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: bannerImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Positioned(
                          right: 0, top: 0, bottom: 0,
                          child: Image.asset(
                            bannerImages[index],
                            width: 180, fit: BoxFit.contain,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.45,
                              child: const Text(
                                '“Feel the Magic\nof Pure\nElegance.”',
                                style: TextStyle(
                                  fontSize: 18, fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500, color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            // 📌 CATEGORY HEADER (Horizontal Pills)
           SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                   // "All" Chip
                   GestureDetector(
                       onTap: () => Navigator.pushNamed(context, '/category', arguments: 'All'),
                       child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                              color: zDarkBlue,
                              borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                   ),
                   // Category Chips
                   ...categories.map((cat) => GestureDetector(
                       onTap: () => Navigator.pushNamed(context, '/category', arguments: cat['name']),
                       child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(cat['name']!, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                       ),
                   )),
                ],
              ),
           ),

            const SizedBox(height: 25),

            // 🔥 PRODUCTS GRID
            _productsFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<dynamic>>(
                future: _productsFuture,
                 builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                        return Text('Error loading products: ${snapshot.error}');
                    } 
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                            child: TextButton.icon(
                                onPressed: () => Navigator.pushNamed(context, '/category'),
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text("View Full Collection"),
                            ),
                        );
                    }

                    final products = snapshot.data!;

                    return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.75,
                        ),
                        itemBuilder: (_, index) {
                            final product = products[index];
                            final isLiked = _favoritesState.isFavorite(product);
                            
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
                                                                  : '${AppConstants.baseUrl.replaceAll('/api', '')}/${product['image']}',
                                                                width: double.infinity, fit: BoxFit.cover,
                                                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                                                            ),
                                                        ),
                                                        Positioned(
                                                            right: 8, top: 8,
                                                            child: GestureDetector(
                                                                onTap: () => _toggleFavorite(product),
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
                                                        Text(product['name'],
                                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: zDarkBlue),
                                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(product['price'], style: const TextStyle(fontSize: 12, color: Colors.black87)),
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 📂 DRAWER
  Widget _buildDrawer() {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    return Drawer(
      backgroundColor: zDarkBlue,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Image.asset('assets/new logo.png', height: 120),
            const SizedBox(height: 50),
            _drawerItem(Icons.home, 'Home', '/home'),
            _drawerItem(Icons.notifications_none, 'Notifications', '/notifications'),
            _drawerItem(Icons.favorite, 'Favorites', '/favorites'), 
            _drawerItem(Icons.smart_toy, 'Chatbot', '/chatbot'),
            _drawerItem(Icons.shopping_cart, 'Cart', '/cart'),
            _drawerItem(Icons.person, 'Account', '/account'),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: () async {
        Navigator.pop(context);
        if (route == '/favorites' || route == '/cart') {
          if (!await AuthHelper.isAuthenticated()) {
            if (context.mounted) {
              AuthHelper.showLoginRedirect(context);
            }
            return;
          }
        }
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }
}
