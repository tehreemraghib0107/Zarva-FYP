import 'package:flutter/material.dart';
import '../widgets/custom_scaffold.dart';
import '../services/cart_service.dart';
import '../services/promotion_service.dart';
import '../services/wishlist_service.dart';
import 'payment_method_screen.dart';
import '../constants.dart';
import '../utils/auth_helper.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final PromotionService _promotionService = PromotionService();
  final WishlistService _wishlistService = WishlistService();
  final TextEditingController _promoController = TextEditingController();
  List<dynamic> _activePromotions = [];
  Map<String, dynamic>? _appliedPromotion;
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isAuthenticated = false;
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_onCartChanged);
    _verifyAuthAndLoad();
  }

  Future<void> _verifyAuthAndLoad() async {
    final authed = await AuthHelper.isAuthenticated();
    if (!mounted) return;
    setState(() {
      _isAuthenticated = authed;
      _authChecked = true;
    });
    if (authed) {
      await _loadActivePromotions();
      await _loadWishlistItems();
    }
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _promoController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {});
  }

  Future<void> _loadWishlistItems() async {
    final items = await _wishlistService.getOutOfStockWishlistProducts();
    if (!mounted) return;
    setState(() {
      _wishlistItems = items;
    });
  }

  Future<void> _openWishlistSheet() async {
    if (!await AuthHelper.requireAuth(context)) return;
    await _loadWishlistItems();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _wishlistItems.isEmpty
              ? const SizedBox(height: 120, child: Center(child: Text('Wishlist is empty')))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Wishlist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._wishlistItems.map((p) {
                      final image = (p['image'] ?? '').toString();
                      final url = image.startsWith('http')
                          ? image
                          : '${AppConstants.baseUrl.replaceAll('/api', '')}/$image';
                      final productId = (p['_id'] ?? p['id'] ?? '').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, width: 44, height: 44, fit: BoxFit.cover),
                        ),
                        title: Text((p['name'] ?? 'Product').toString()),
                        subtitle: const Text('Out of stock'),
                        trailing: IconButton(
                          onPressed: productId.isEmpty
                              ? null
                              : () async {
                                  final removed = await _wishlistService.remove(productId);
                                  if (!mounted) return;
                                  if (!removed) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not remove item from wishlist')),
                                    );
                                    return;
                                  }
                                  await _loadWishlistItems();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Removed from wishlist')),
                                  );
                                  Navigator.pop(context);
                                  _openWishlistSheet();
                                },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Remove from wishlist',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/product_details', arguments: p);
                        },
                      );
                    }),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _loadActivePromotions() async {
    final promos = await _promotionService.getActivePromotions();
    if (!mounted) return;
    setState(() {
      _activePromotions = promos;
      if (_activePromotions.isNotEmpty && _appliedPromotion == null) {
        _appliedPromotion = _activePromotions.first as Map<String, dynamic>;
      }
    });
  }

  double get _discountPercent {
    final selected = _appliedPromotion;
    if (selected == null) return 0;
    final p = selected['discountPercent'];
    if (p is num) return p.toDouble();
    return double.tryParse('$p') ?? 0;
  }

  double get _discountAmount => (_cartService.subTotal * _discountPercent) / 100.0;
  double get _discountedSubtotal => (_cartService.subTotal - _discountAmount).clamp(0, double.infinity);
  double get _shipping => 250.0;
  double get _grandTotal => _discountedSubtotal + _shipping;

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    final res = await _promotionService.validateCode(code);
    if (!mounted) return;
    if (!res['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Invalid promo code')));
      return;
    }
    setState(() {
      _appliedPromotion = res['promo'] as Map<String, dynamic>;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo applied')));
  }

  Widget _buildGuestLockedBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 72, color: Color(0xFF0B1C2D)),
            const SizedBox(height: 20),
            const Text(
              'Shopping Vault Locked',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0B1C2D)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign up or log in to view your cart, apply promos, and complete checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => AuthHelper.showLoginRedirect(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1C2D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Join ZARVA / Login',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;

    if (!_authChecked) {
      return const CustomScaffold(
        currentIndex: 3,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthenticated) {
      return CustomScaffold(
        currentIndex: 3,
        body: _buildGuestLockedBody(),
      );
    }
    
    return CustomScaffold(
      currentIndex: 3,
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: _openWishlistSheet,
              icon: Icon(
                _wishlistItems.isNotEmpty ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                color: const Color(0xFFFF9800),
              ),
            ),
            if (_wishlistItems.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    _wishlistItems.length > 99 ? '99+' : '${_wishlistItems.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ],
      body: _cartService.items.isEmpty 
        ? Center(child: Text("Your cart is empty", style: TextStyle(fontSize: 18, color: isDark ? Colors.white70 : Colors.grey)))
        : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _cartService.items.length,
              itemBuilder: (context, index) {
                return _cartItem(_cartService.items[index]);
              },
            ),
          ),

          // 🔽 PROMO & BOTTOM BAR
            Container(
             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
             ),
             child: Column(
                 children: [
                     // Promo Code
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16),
                       decoration: BoxDecoration(
                         color: isDark ? Colors.grey[800] : Colors.grey.shade100,
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: Row(
                         children: [
                           Expanded(
                             child: TextField(
                               controller: _promoController,
                               decoration: const InputDecoration(
                                 hintText: 'Promo/Student Code or Vouchers',
                                 border: InputBorder.none,
                                 hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                               ),
                             ),
                           ),
                           TextButton(
                             onPressed: _applyPromoCode,
                             child: const Text('Apply'),
                           )
                         ],
                       ),
                     ),
                     if (_activePromotions.isNotEmpty) ...[
                       const SizedBox(height: 10),
                       DropdownButtonFormField<String>(
                         initialValue: _appliedPromotion?['code']?.toString(),
                         decoration: InputDecoration(
                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                           filled: true,
                           fillColor: Colors.grey.shade100,
                           border: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(12),
                             borderSide: BorderSide.none,
                           ),
                         ),
                         hint: const Text('Select active promo'),
                         items: _activePromotions.map((p) {
                           final code = p['code']?.toString() ?? '';
                           final off = p['discountPercent']?.toString() ?? '0';
                           return DropdownMenuItem<String>(
                             value: code,
                             child: Text('$code ($off% OFF)'),
                           );
                         }).toList(),
                         onChanged: (val) {
                           if (val == null) return;
                           setState(() {
                             _appliedPromotion = _activePromotions.firstWhere((p) => p['code'] == val) as Map<String, dynamic>;
                           });
                         },
                       ),
                     ],
                     const SizedBox(height: 20),
                     
                     // Totals
                     Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                       Text("Sub Total", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 14)),
                       Text("PKR ${_cartService.subTotal.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                     ]),
                     if (_discountPercent > 0) ...[
                       const SizedBox(height: 10),
                       Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                         Text("Promo (${_appliedPromotion?['code'] ?? ''} - ${_discountPercent.toStringAsFixed(0)}%)",
                             style: const TextStyle(color: Colors.grey, fontSize: 14)),
                         Text("- PKR ${_discountAmount.toStringAsFixed(0)}",
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                       ]),
                     ],
                     const SizedBox(height: 10),
                     Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                       Text("Shipping charges", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 14)),
                       Text("PKR ${_shipping.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                     ]),
                     const SizedBox(height: 20),

                     // Payment Button (Blue)
                     SizedBox(
                         width: double.infinity,
                         height: 55,
                         child: ElevatedButton(
                             onPressed: () async {
                               if (_cartService.items.isEmpty) return;
                               if (!await AuthHelper.requireAuth(context)) return;

                               // Convert CartItems to dynamic map for transfer
                               final cartItemsData = _cartService.items.map((item) => {
                                 'id': item.id,
                                 'name': item.name,
                                 'price': 'PKR ${item.price.toStringAsFixed(0)}',
                                 'quantity': item.quantity,
                                 'size': item.selectedSize,
                                 'image': item.image,
                                 'category': item.category,
                               }).toList();

                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => PaymentMethodScreen(
                                     items: cartItemsData,
                                     subtotal: _discountedSubtotal,
                                     promoCode: _appliedPromotion?['code']?.toString(),
                                     discountPercent: _discountPercent,
                                     discountAmount: _discountAmount,
                                   ),
                                 ),
                                );
                             },
                             style: ElevatedButton.styleFrom(
                                 backgroundColor: zDarkBlue,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                             ),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                  Text("Total: PKR ${_grandTotal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  const Text("Proceed to Pay", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                               ],
                             ),
                         ),
                     )

                 ],
             ),
          ),
        ],
      ),
    );
  }

  // 🧾 CART ITEM
  Widget _cartItem(CartItem item) {
    const Color zDarkBlue = Color(0xFF0B1C2D); 

    return Dismissible(
      key: Key('${item.id}_${item.selectedSize}'),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _cartService.removeFromCart(item.id, selectedSize: item.selectedSize);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} removed from cart')));
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: zDarkBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            // IMAGE
            ClipRRect(
               borderRadius: BorderRadius.circular(15),
               child: Image.network(
                  item.image.startsWith('http') 
                    ? item.image 
                    : '${AppConstants.baseUrl.replaceAll('/api', '')}/${item.image}',
                  width: 80, height: 80, fit: BoxFit.contain,
                  errorBuilder: (_,__,___) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.error))
               ),
            ),
            
            const SizedBox(width: 16),

            // DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                   const SizedBox(height: 4),
                   Text("PKR ${item.price.toStringAsFixed(0)}", style: const TextStyle(color: zDarkBlue, fontWeight: FontWeight.bold, fontSize: 14)), 
                   const SizedBox(height: 4),
                   Text(item.category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                   if (item.selectedSize.isNotEmpty)
                     Text('US Size: ${item.selectedSize}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

            // QTY CONTROLS
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F5), 
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                     GestureDetector(
                       onTap: () => _cartService.incrementQuantity(item.id, selectedSize: item.selectedSize),
                       child: Container(
                         padding: const EdgeInsets.all(8),
                         child: const Icon(Icons.add, size: 16, color: Colors.black),
                       ),
                     ),
                     Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                     GestureDetector(
                       onTap: () => _cartService.decrementQuantity(item.id, selectedSize: item.selectedSize),
                       child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.remove, size: 16, color: Colors.black),
                       ),
                     ),
                 ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
