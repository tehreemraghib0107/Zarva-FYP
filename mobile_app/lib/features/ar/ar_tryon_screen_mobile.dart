import 'package:flutter/material.dart';
import 'ar_jewelry_screen.dart';

/// Mobile/native entry — delegates to ML Kit camera AR screen.
class ArTryOnScreen extends StatelessWidget {
  final String productCategory;
  final String productImageUrl;
  final String? productName;
  final String? productCode;

  const ArTryOnScreen({
    super.key,
    required this.productCategory,
    required this.productImageUrl,
    this.productName,
    this.productCode,
  });

  @override
  Widget build(BuildContext context) {
    return ARJewelryScreen(
      productCategory: productCategory,
      productImageUrl: productImageUrl,
      productName: productName,
      productCode: productCode,
    );
  }
}
