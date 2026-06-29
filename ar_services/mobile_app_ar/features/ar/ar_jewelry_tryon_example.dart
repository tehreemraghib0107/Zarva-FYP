import 'package:flutter/material.dart';

import '../../config/ar_asset_config.dart';
import '../../widgets/ar_jewelry_tryon_screen.dart';

/// Example: How to integrate the new 3D AR jewelry try-on screen.
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => const ArJewelryTryOnExampleScreen(),
///   ),
/// );
/// ```

class ArJewelryTryOnExampleScreen extends StatelessWidget {
  const ArJewelryTryOnExampleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D AR Jewelry Try-On'),
        backgroundColor: const Color(0xFF0B1C2D),
      ),
      body: const ArJewelryTryOnScreen(
        /// Replace with your actual model URLs
        earringsModelUrl: ArAssetConfig.earringsModelUrl,
        necklaceModelUrl: ArAssetConfig.necklaceModelUrl,

        /// Optional: for local asset hosting
        // assetBasePath: ArAssetConfig.assetBasePath,
        productName: 'Luxury Jewelry',
        debugMode: ArAssetConfig.debugMode,
      ),
    );
  }
}

/// Alternative: Integration with product detail screen
class ProductArTryOnButton extends StatelessWidget {
  final String productName;
  final String earringsModelUrl;
  final String necklaceModelUrl;
  final bool isJewelryCategory;

  const ProductArTryOnButton({
    Key? key,
    required this.productName,
    required this.earringsModelUrl,
    required this.necklaceModelUrl,
    this.isJewelryCategory = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isJewelryCategory
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArJewelryTryOnScreen(
                  earringsModelUrl: earringsModelUrl,
                  necklaceModelUrl: necklaceModelUrl,
                  productName: productName,
                ),
              ),
            )
          : null,
      icon: const Icon(Icons.visibility),
      label: const Text('Try in AR'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isJewelryCategory
            ? const Color(0xFFFFD700)
            : Colors.grey,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
