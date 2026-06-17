import 'package:flutter/material.dart';

class ArTryOnScreen extends StatelessWidget {
  final String productCategory;
  final String productImageUrl;
  final String? productName;

  const ArTryOnScreen({
    super.key,
    required this.productCategory,
    required this.productImageUrl,
    this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Try-On')),
      body: const Center(
        child: Text(
          'AR Try-On is available on web browsers and mobile devices.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
