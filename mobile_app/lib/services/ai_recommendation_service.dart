import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// Immutable snapshot for one outbound request — prevents stale UI state leaking.
class StyleRecommendationPayload {
  final String userId;
  final String dressColor;
  final String skinTone;
  final String manualNeckline;
  final String userQuery;
  final String imagePath;
  final Uint8List? imageBytes;
  final String imageFilename;

  const StyleRecommendationPayload({
    required this.userId,
    required this.dressColor,
    required this.skinTone,
    required this.manualNeckline,
    required this.userQuery,
    required this.imagePath,
    required this.imageBytes,
    required this.imageFilename,
  });
}

class AiRecommendationService {
  static const String recommendUrl = '${AppConstants.baseUrl}/ai/recommend';
  static const String textChatUrl = '${AppConstants.baseUrl}/chat/text';

  static final Random _random = Random();

  /// Fresh boundary token per request so proxies do not reuse form chunks.
  static String _newMultipartBoundary() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0x7FFFFFFF);
    return 'zarva_${stamp}_$salt';
  }

  /// Scenario A — image + optional metadata + user text query.
  static Future<Map<String, dynamic>> sendStyleRecommendation(
    StyleRecommendationPayload payload,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(recommendUrl));
    final boundary = _newMultipartBoundary();

    request.fields['userId'] = payload.userId;
    request.fields['dressColor'] = payload.dressColor;
    request.fields['skinTone'] = payload.skinTone;
    request.fields['manualNeckline'] = payload.manualNeckline;
    request.fields['userQuery'] = payload.userQuery.trim();

    request.headers['X-Multipart-Boundary'] = boundary;
    request.headers['X-Request-Id'] = boundary;

    final path = payload.imagePath.trim();
    if (path.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          path,
          filename: payload.imageFilename,
        ),
      );
    } else if (payload.imageBytes != null && payload.imageBytes!.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          payload.imageBytes!,
          filename: payload.imageFilename,
        ),
      );
    } else {
      return {
        'success': false,
        'message': 'No image bytes available for upload.',
      };
    }

    return _parseResponse(
      await request.send().timeout(const Duration(seconds: 120)),
    );
  }

  /// Scenario B — text-only fashion queries.
  static Future<Map<String, dynamic>> sendTextQuery({
    required String userId,
    required String userQuery,
  }) async {
    final boundary = _newMultipartBoundary();
    final response = await http
        .post(
          Uri.parse(textChatUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Request-Id': boundary,
          },
          body: {
            'userId': userId,
            'userQuery': userQuery.trim(),
          },
        )
        .timeout(const Duration(seconds: 45));

    return _parseJsonBody(response.statusCode, response.body);
  }

  static Future<Map<String, dynamic>> _parseResponse(
    http.StreamedResponse streamed,
  ) async {
    final body = await streamed.stream.bytesToString();
    return _parseJsonBody(streamed.statusCode, body);
  }

  static Map<String, dynamic> _parseJsonBody(int statusCode, String body) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'message': 'Invalid response from styling server.',
        'raw': body,
      };
    }

    if (statusCode >= 200 && statusCode < 300) {
      return {
        'success': data['success'] != false,
        'data': data,
        'recommendation': data['recommendation']?.toString() ?? '',
      };
    }

    return {
      'success': false,
      'message': data['error']?.toString() ??
          data['msg']?.toString() ??
          'Request failed ($statusCode).',
      'data': data,
    };
  }
}
