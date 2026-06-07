/// Sanitizes ML / API recommendation strings for luxury retail chat display.
class ZarbotResponseFormatter {
  /// Maps raw exceptions to customer-safe chat copy (no dart:io / stack traces).
  static String userFriendlyError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('multipartfile') && lower.contains('dart:io')) {
      return 'Photo upload on this browser failed. Please try again, or run the app '
          'on Android/iOS for camera uploads.';
    }
    if (lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable')) {
      return 'ZarBot cannot reach the styling server. Start the backend on port 5000 '
          'and the AI service on port 8000, then try again.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The styling request took too long. Please try again with a smaller photo.';
    }
    if (lower.contains('cors')) {
      return 'Browser blocked the request. Ensure the Node.js API allows CORS from this app.';
    }

    return 'Something went wrong while analyzing your look. Please try again in a moment.';
  }

  static final List<RegExp> _mlNoisePatterns = [
    RegExp(r'Detected focal jewelry type in reference:\s*\w+\.?\s*', caseSensitive: false),
    RegExp(r'predicted_cultural_style:\s*[\w\s]+\.?\s*', caseSensitive: false),
    RegExp(r'status:\s*success\.?\s*', caseSensitive: false),
    RegExp(r'ZARVA Styling Insight\s*—\s*Neckline:\s*[\w/]+\.\s*', caseSensitive: false),
    RegExp(r'Recommended accent:\s*\w+\s*\([^)]+\)\.\s*', caseSensitive: false),
    RegExp(r"Dress palette '[^']*' against \w+ skin tone\s*—\s*", caseSensitive: false),
    RegExp(r'\{[^}]*\}'),
    RegExp(r'\[[^\]]*\]'),
  ];

  static String sanitize(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    for (final pattern in _mlNoisePatterns) {
      text = text.replaceAll(pattern, '');
    }

    text = text
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .trim();

    if (text.endsWith(',')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text;
  }

  static ParsedZarbotResponse parse(Map<String, dynamic> data) {
    final rawRecommendation = data['recommendation']?.toString() ?? '';
    final insight = sanitize(
      data['stylingInsight']?.toString() ??
          _extractAfterLabel(rawRecommendation, 'insight') ??
          rawRecommendation,
    );
    final why = sanitize(
      data['whyThisWorks']?.toString() ??
          _extractAfterLabel(rawRecommendation, 'why') ??
          _defaultWhy(data),
    );

    final isImageRec = data.containsKey('neckline');
    final neckline = isImageRec
        ? _displayNeckline(
            data['neckline']?.toString() ?? '',
            data['manualNeckline']?.toString(),
          )
        : 'Style Q&A';
    final accent = isImageRec
        ? _displayAccent(
            data['recommendedAccentLabel']?.toString(),
            data['recommendedJewelryType']?.toString(),
          )
        : 'Guidance';
    final theme = data['culturalTheme']?.toString() ??
        (data['jewelryStyle'] != null
            ? '${data['jewelryStyle']} Heritage'
            : 'ZARVA Curated');

    return ParsedZarbotResponse(
      stylingInsight: insight.isNotEmpty ? insight : sanitize(rawRecommendation),
      whyThisWorks: why,
      necklineBadge: neckline,
      accentBadge: accent,
      themeBadge: theme,
      isRecommendation: isImageRec,
    );
  }

  static String? _extractAfterLabel(String text, String kind) {
    if (text.isEmpty) return null;
    return null;
  }

  static String _defaultWhy(Map<String, dynamic> data) {
    final piece = data['recommendedJewelryType']?.toString() ?? 'jewelry';
    final neck = data['neckline']?.toString() ?? 'your neckline';
    return 'This pairing follows ZARVA styling rules — $neck compositions balance best with '
        '$piece accents for South Asian formal silhouettes.';
  }

  static String _displayNeckline(String detected, String? manual) {
    if (manual != null && manual.trim().isNotEmpty) return manual.trim();
    if (detected.isEmpty) return 'Auto-detected';
    if (detected.toLowerCase().contains('neck')) return detected;
    return '$detected Neck';
  }

  static String _displayAccent(String? label, String? rawType) {
    if (label != null && label.isNotEmpty) return label;
    if (rawType == null || rawType.isEmpty) return 'Jewelry';
    if (rawType.toLowerCase() == 'earring') return 'Earrings';
    if (rawType.toLowerCase() == 'necklace') return 'Necklace';
    return rawType[0].toUpperCase() + rawType.substring(1);
  }
}

class ParsedZarbotResponse {
  final String stylingInsight;
  final String whyThisWorks;
  final String necklineBadge;
  final String accentBadge;
  final String themeBadge;
  final bool isRecommendation;

  const ParsedZarbotResponse({
    required this.stylingInsight,
    required this.whyThisWorks,
    required this.necklineBadge,
    required this.accentBadge,
    required this.themeBadge,
    required this.isRecommendation,
  });
}
