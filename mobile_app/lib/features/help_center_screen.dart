import 'package:flutter/material.dart';
import '../widgets/custom_scaffold.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color zDarkBlue = Color(0xFF0B1C2D);

    return CustomScaffold(
      currentIndex: 4,
      forceShowBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help Center',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: zDarkBlue),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Welcome to Zarva Support. FAQs:\n'
                '1. How does ZarBot work? It uses YOLO-World and MobileNetV3 architectures to evaluate your outfit configurations dynamically.\n'
                '2. Payment methods? We securely accept card processing streams and Cash on Delivery (COD).',
                style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
