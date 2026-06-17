import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../constants.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();
  Future<List<dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchNotifications(limit: 100);
    _future?.then((_) => _service.markAllAsRead());
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1C2D),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1C2D),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),

        // ✅ ALWAYS GO TO HOME
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),

      body: _future == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No notifications yet', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final n = items[index] as Map<String, dynamic>;
              final createdAtRaw = n['createdAt']?.toString();
              final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
              final title = (n['title'] ?? 'Notification').toString();
              final message = (n['message'] ?? '').toString();
              final type = (n['type'] ?? 'general').toString();
              final metadata = (n['metadata'] is Map<String, dynamic>) ? n['metadata'] as Map<String, dynamic> : <String, dynamic>{};
              final imageRaw = metadata['image']?.toString();
              final imageUrl = (imageRaw != null && imageRaw.isNotEmpty)
                  ? (imageRaw.startsWith('http')
                      ? imageRaw
                      : '${AppConstants.baseUrl.replaceAll('/api', '')}/$imageRaw')
                  : null;

              IconData icon = Icons.notifications;
              if (type == 'product') icon = Icons.new_releases;
              if (type == 'promotion') icon = Icons.local_offer;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              height: 42,
                              width: 42,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 42,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: Colors.black),
                              ),
                            ),
                          )
                        : Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: Colors.black),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(message, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text(
                            createdAt != null ? _timeAgo(createdAt) : '',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
