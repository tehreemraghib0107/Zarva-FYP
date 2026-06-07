import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/review_service.dart';
import '../services/wishlist_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../utils/auth_helper.dart';
import 'payment_method_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String? _selectedSize;
  final ReviewService _reviewService = ReviewService();
  final WishlistService _wishlistService = WishlistService();
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  List<dynamic> _reviews = [];
  bool _loadingReviews = true;
  bool _isFavorite = false;
  
  // Available ring sizes
  final List<String> _ringSizes = ['3.0', '3.5', '4.0', '4.5', '5.0', '5.5', '6.0', '6.5', '7.0', '7.5', '8.0', '8.5', '9.0', '9.5', '10.0'];

  Future<void> _launchWhatsApp() async {
    // Replace with the actual admin number
    final Uri url = Uri.parse('https://wa.me/923234747062'); 
    debugPrint('Launching WhatsApp URL: $url');
    try {
      if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
        debugPrint('Could not launch $url');
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final id = _extractProductId(widget.product);
    if (id == null) return;
    final inWishlist = await _wishlistService.isInWishlist(id);
    if (!mounted) return;
    setState(() {
      _isFavorite = inWishlist;
    });
  }

  bool _validateRingSize(bool isRing) {
    if (isRing && (_selectedSize == null || _selectedSize!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select ring size')),
      );
      return false;
    }
    return true;
  }

  Map<String, dynamic> _productForCart(bool isRing) {
    return {
      ...widget.product,
      'selectedSize': isRing ? _selectedSize : '',
    };
  }

  Future<void> _handleAddToCart(bool isRing) async {
    if (!await AuthHelper.requireAuth(context)) return;
    if (!_validateRingSize(isRing)) return;

    final added = await CartService().addToCart(_productForCart(isRing));
    if (!added) {
      if (!context.mounted) return;
      AuthHelper.showLoginRedirect(context);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${widget.product['name']} to cart!'),
        backgroundColor: const Color(0xFF0B1C2D),
        duration: const Duration(seconds: 1),
        action: SnackBarAction(
          label: 'VIEW CART',
          textColor: Colors.white,
          onPressed: () => Navigator.pushReplacementNamed(context, '/cart'),
        ),
      ),
    );
  }

  Future<void> _handleBuyNow(bool isRing) async {
    if (!await AuthHelper.requireAuth(context)) return;
    if (!_validateRingSize(isRing)) return;

    final product = _productForCart(isRing);
    final added = await CartService().addToCart(product);
    if (!added) {
      if (!context.mounted) return;
      AuthHelper.showLoginRedirect(context);
      return;
    }

    final priceStr = product['price'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
    final price = double.tryParse(priceStr) ?? 0.0;
    final productId = (product['_id'] ?? product['id']).toString();

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          items: [
            {
              'id': productId,
              'name': product['name'],
              'price': 'PKR ${price.toStringAsFixed(0)}',
              'quantity': 1,
              'size': product['selectedSize'] ?? '',
              'image': product['image'],
              'category': product['category'] ?? 'Jewelry',
            },
          ],
          subtotal: price,
        ),
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    if (!await AuthHelper.requireAuth(context)) return;
    final id = _extractProductId(widget.product);
    if (id == null) return;
    final nowFav = await _wishlistService.toggle(id);
    if (nowFav == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update wishlist. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isFavorite = nowFav);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(nowFav ? 'Added to wishlist' : 'Removed from wishlist')),
    );
  }

  void _showSizeChart() {
    const rows = [
      ['3', 'F', '44', '14.0', '44.0'],
      ['3.5', 'G', '45', '14.4', '45.2'],
      ['4', 'H', '46', '14.8', '46.5'],
      ['4.5', 'I', '48', '15.2', '47.8'],
      ['5', 'J', '49', '15.7', '49.3'],
      ['5.5', 'K', '50', '16.0', '50.3'],
      ['6', 'L', '51', '16.5', '51.8'],
      ['6.5', 'M', '52', '16.9', '53.1'],
      ['7', 'N', '54', '17.3', '54.4'],
      ['7.5', 'O', '55', '17.7', '55.7'],
      ['8', 'P', '57', '18.1', '57.0'],
      ['8.5', 'Q', '58', '18.5', '58.3'],
      ['9', 'R', '59', '19.0', '59.5'],
      ['9.5', 'S', '60', '19.4', '60.8'],
      ['10', 'T', '62', '19.8', '62.1'],
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ring Size Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('US')),
                        DataColumn(label: Text('UK')),
                        DataColumn(label: Text('EU')),
                        DataColumn(label: Text('Diameter')),
                        DataColumn(label: Text('Circumference')),
                      ],
                      rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList())).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadReviews() async {
    final productId = widget.product['_id']?.toString();
    if (productId == null) return;
    final data = await _reviewService.getProductReviews(productId);
    if (!mounted) return;
    setState(() {
      _reviews = data;
      _loadingReviews = false;
    });
  }

  Future<void> _publishReview() async {
    final productId = widget.product['_id']?.toString();
    if (productId == null) return;
    final comment = _reviewController.text.trim();
    if (_selectedRating == 0 && comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a rating or comment')),
      );
      return;
    }
    final res = await _reviewService.submitReview(
      productId: productId,
      rating: _selectedRating > 0 ? _selectedRating : null,
      comment: comment.isNotEmpty ? comment : null,
    );
    if (!mounted) return;
    if (res['success']) {
      _reviewController.clear();
      setState(() => _selectedRating = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted for admin approval')),
      );
      await _loadReviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to submit review')),
      );
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    const Color zGreyBg = Color(0xFFF2F2F2); // Light grey for product background
    
    final bool isRing = widget.product['category'] == 'Rings';
    
    int remaining = 1;
    if (widget.product['inventory'] != null) {
      remaining = widget.product['inventory']['remaining'] ?? 1;
    }
    final bool isOutOfStock = remaining <= 0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top Half - Product Image & Back Button
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  color: zGreyBg,
                  child: Center(
                    child: Hero(
                      tag: widget.product['_id'] ?? widget.product['name'],
                      child: Image.network(
                        (widget.product['image'] ?? '').toString().startsWith('http')
                          ? widget.product['image']
                          : '${AppConstants.baseUrl.replaceAll('/api', '')}/${widget.product['image'] ?? 'assets/new logo.png'}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_,__,___) => const Icon(Icons.error, size: 50),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                      ),
                      child: const Icon(Icons.arrow_back, color: zDarkBlue),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Camera Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: zDarkBlue),
                      ),
                      const SizedBox(width: 12),
                      // WhatsApp Icon
                      GestureDetector(
                        onTap: _launchWhatsApp,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
                          ),
                          // Increased size to 28 to better match the camera icon visually
                          child: Image.asset(
                            'assets/whatsapp.png', 
                            width: 28, 
                            height: 28,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 20),
                          ), 
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Half - Details
          Expanded(
            flex: 6, // Slightly larger bottom area
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product['name'] ?? 'Product Name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: zDarkBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.product['price'] ?? 'PKR 0',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: zDarkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      widget.product['description'] ?? "Handcrafted featuring delicate stones set in polished metal. Perfect for stacking or wearing alone to add a touch of elegance to your daily look.",
                      style: const TextStyle(
                        color: Colors.grey,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (isRing) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Ring Size (US)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: zDarkBlue,
                            ),
                          ),
                          IconButton(
                            onPressed: _showSizeChart,
                            icon: const Icon(Icons.straighten, color: zDarkBlue),
                            tooltip: 'View size chart',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _ringSizes.map((size) {
                          final isSelected = _selectedSize == size;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSize = size;
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.grey[300] : Colors.white,
                                border: Border.all(
                                  color: isSelected ? zDarkBlue : Colors.grey[300]!,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                size,
                                style: TextStyle(
                                  color: isSelected ? zDarkBlue : Colors.black54,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 30),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: OutlinedButton(
                              onPressed: isOutOfStock ? null : () => _handleAddToCart(isRing),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isOutOfStock ? Colors.grey : zDarkBlue),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                isOutOfStock ? "Out of Stock" : "Add to Cart",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isOutOfStock ? Colors.grey[600] : zDarkBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton(
                              onPressed: isOutOfStock ? null : () => _handleBuyNow(isRing),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOutOfStock ? Colors.grey : zDarkBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: Colors.grey[300],
                                disabledForegroundColor: Colors.grey[600],
                              ),
                              child: Text(
                                isOutOfStock ? "Unavailable" : "Buy Now",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isOutOfStock ? Colors.grey[600] : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isOutOfStock) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 55,
                            width: 55,
                            child: OutlinedButton(
                              onPressed: _toggleWishlist,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                side: BorderSide(
                                  color: _isFavorite ? const Color(0xFFFFA726) : Colors.grey.shade300,
                                ),
                                backgroundColor: _isFavorite ? const Color(0xFFFFF3E0) : Colors.white,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.center,
                              ),
                              child: Center(
                                child: Icon(
                                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                  color: _isFavorite ? const Color(0xFFFF9800) : const Color(0xFFFFB74D),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Write a review',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: zDarkBlue),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (i) {
                              final star = i + 1;
                              return IconButton(
                                onPressed: () => setState(() => _selectedRating = star),
                                icon: Icon(
                                  _selectedRating >= star ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                ),
                              );
                            }),
                          ),
                          TextField(
                            controller: _reviewController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Share your experience (optional)',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _publishReview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: zDarkBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Publish Review', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Customer Reviews',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: zDarkBlue),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingReviews)
                      const Center(child: CircularProgressIndicator())
                    else if (_reviews.isEmpty)
                      const Text('No approved reviews yet.', style: TextStyle(color: Colors.grey))
                    else
                      ..._reviews.map((r) {
                        final user = (r['userId'] is Map<String, dynamic>) ? r['userId'] as Map<String, dynamic> : <String, dynamic>{};
                        final rating = (r['rating'] is num) ? (r['rating'] as num).toInt() : 0;
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['name']?.toString() ?? 'Customer',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (rating > 0)
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating ? Icons.star : Icons.star_border,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              if ((r['comment'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text((r['comment'] ?? '').toString()),
                                ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ]
      ),
    );
  }

  String? _extractProductId(Map<String, dynamic> p) {
    if (p['_id'] != null && p['_id'].toString().isNotEmpty) return p['_id'].toString();
    if (p['id'] != null && p['id'].toString().isNotEmpty) return p['id'].toString();
    final raw = p['productId'];
    if (raw is Map && raw['_id'] != null) return raw['_id'].toString();
    if (raw != null && raw.toString().isNotEmpty) return raw.toString();
    return null;
  }
}
