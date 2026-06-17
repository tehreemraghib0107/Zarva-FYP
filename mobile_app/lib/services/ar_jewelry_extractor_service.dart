import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ArJewelryExtractorService {
  /// Runs YOLO + background removal on the product photo and returns a transparent PNG data URL.
  static Future<String?> extractOverlay(String imageUrl, String category) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/ai/extract-jewelry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageUrl': imageUrl,
          'category': category,
        }),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      final overlay = data['overlayDataUrl']?.toString();
      if (overlay == null || overlay.isEmpty) return null;
      return overlay;
    } catch (_) {
      return null;
    }
  }
}
