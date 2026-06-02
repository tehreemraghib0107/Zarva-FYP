import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class NotificationService {
  static const String baseUrl = '${AppConstants.baseUrl}/notifications';
  static const String _seenAtKey = 'notifications_seen_at';

  Future<List<dynamic>> fetchNotifications({int limit = 50}) async {
    final response = await http.get(Uri.parse('$baseUrl?limit=$limit'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<int> getUnreadCount({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final seenAtRaw = prefs.getString(_seenAtKey);
    final seenAt = seenAtRaw != null ? DateTime.tryParse(seenAtRaw) : null;
    final items = await fetchNotifications(limit: limit);

    if (seenAt == null) return items.length;

    int count = 0;
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final createdAtRaw = raw['createdAt']?.toString();
      final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
      if (createdAt != null && createdAt.isAfter(seenAt)) count++;
    }
    return count;
  }

  Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenAtKey, DateTime.now().toIso8601String());
  }
}

