import 'package:flutter/material.dart';

import '../../config/ar_asset_config.dart';
import '../../services/ar_product_model_service.dart';
import '../../widgets/ar_jewelry_tryon_screen.dart';

/// AR Try-On Screen integrated with product data from backend.
///
/// This screen fetches 3D model URLs from the backend API based on the product ID
/// and passes them to the AR widget for real-time jewelry try-on.
class ArProductTryOnScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String productCategory;

  const ArProductTryOnScreen({
    Key? key,
    required this.productId,
    required this.productName,
    required this.productCategory,
  }) : super(key: key);

  @override
  State<ArProductTryOnScreen> createState() => _ArProductTryOnScreenState();
}

class _ArProductTryOnScreenState extends State<ArProductTryOnScreen> {
  late Future<Map<String, String?>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    _modelsFuture = ArProductModelService.fetchProductArModels(
      widget.productId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AR Try-On — ${widget.productName}'),
        backgroundColor: const Color(0xFF0B1C2D),
      ),
      body: FutureBuilder<Map<String, String?>>(
        future: _modelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFFD700)),
                  const SizedBox(height: 16),
                  Text(
                    'Loading 3D models for ${widget.productName}...',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load AR models: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final models = snapshot.data ?? {};
          final earringsUrl =
              models['earringsModelUrl'] ?? ArAssetConfig.earringsModelUrl;
          final necklaceUrl =
              models['necklaceModelUrl'] ?? ArAssetConfig.necklaceModelUrl;

          return ArJewelryTryOnScreen(
            earringsModelUrl: earringsUrl,
            necklaceModelUrl: necklaceUrl,
            productName: widget.productName,
            debugMode: ArAssetConfig.debugMode,
          );
        },
      ),
    );
  }
}
