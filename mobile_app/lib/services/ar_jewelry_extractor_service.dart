import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ArJewelryExtractorService {
  static Future<String?> extractOverlay(String imageUrl, String category) async {
    try {
      if (imageUrl.isEmpty) {
        return null;
      }

      // Fetch the image bytes to support local server URLs (e.g. http://10.0.2.2:5000)
      final imgRes = await http.get(Uri.parse(imageUrl));
      if (imgRes.statusCode != 200) {
        debugPrint('ArJewelryExtractorService: Failed to download image from $imageUrl');
        return null;
      }
      final Uint8List imageBytes = imgRes.bodyBytes;

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );
      
      request.headers['X-Api-Key'] = 'SUWFLLticifjwPLhjva7b2Re';
      request.fields['size'] = 'auto';
      request.fields['format'] = 'png';
      
      final filename = imageUrl.split('/').last.split('?').first;
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: filename.isNotEmpty ? filename : 'image.png',
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        Uint8List responseData = await response.stream.toBytes();
        String base64String = base64Encode(responseData);
        return 'data:image/png;base64,$base64String';
      } else {
        debugPrint('ArJewelryExtractorService Error: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('ArJewelryExtractorService error: $e');
      return null;
    }
  }
}
