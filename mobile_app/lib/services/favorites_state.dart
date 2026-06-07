import 'package:flutter/foundation.dart';
import '../utils/product_id_helper.dart';
import 'product_service.dart';

/// Shared favorites cache so Home / Category hearts stay in sync after navigation.
class FavoritesState extends ChangeNotifier {
  static final FavoritesState _instance = FavoritesState._internal();
  factory FavoritesState() => _instance;
  FavoritesState._internal();

  final ProductService _productService = ProductService();
  Set<String> _ids = {};
  bool _loading = false;

  Set<String> get ids => _ids;
  bool get isLoading => _loading;

  bool isFavorite(dynamic productOrId) {
    final id = productOrId is String
        ? productOrId
        : normalizeProductId(productOrId is Map ? (productOrId['_id'] ?? productOrId['id']) : productOrId);
    if (id == null) return false;
    return _ids.contains(id);
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final favs = await _productService.getFavorites();
      _ids = favoriteIdsFromApi(favs);
    } catch (_) {
      _ids = {};
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool?> toggle(String productId) async {
    final normalized = normalizeProductId(productId);
    if (normalized == null) return null;

    final wasLiked = _ids.contains(normalized);
    if (wasLiked) {
      _ids.remove(normalized);
    } else {
      _ids.add(normalized);
    }
    notifyListeners();

    final result = await _productService.toggleFavorite(normalized);
    if (result == null) {
      if (wasLiked) {
        _ids.add(normalized);
      } else {
        _ids.remove(normalized);
      }
      notifyListeners();
      return null;
    }
    await refresh();
    return result;
  }
}
