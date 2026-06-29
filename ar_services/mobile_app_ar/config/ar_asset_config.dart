/// AR model asset URLs configuration.
///
/// Update these URLs to point to your hosted GLB models.
/// Supports both CDN URLs and Flutter web asset paths.

class ArAssetConfig {
  /// Production earrings model URL
  static const String earringsModelUrl =
      'https://cdn.example.com/models/jewelry/earrings.glb';

  /// Production necklace model URL
  static const String necklaceModelUrl =
      'https://cdn.example.com/models/jewelry/necklace.glb';

  /// Alternative: if serving from Flutter web assets
  /// Use this with [ArJewelryTryOnScreen.assetBasePath = 'assets/models/']
  static const String assetBasePath = 'assets/models/';

  /// Debug mode (shows FPS and landmark info)
  static const bool debugMode = false;

  /// Smoothing factor for temporal filtering (0.0 = no smoothing, 1.0 = maximum)
  /// Higher values reduce jitter but may cause lag
  static const double smoothingAlpha = 0.78;
}
