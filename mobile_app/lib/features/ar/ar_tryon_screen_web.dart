import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/ar_web_bridge.dart';
import '../../services/ar_jewelry_extractor_service.dart';

/// Chrome/web AR try-on — WebRTC camera + MediaPipe landmarks 234/454/152.
class ArTryOnScreen extends StatefulWidget {
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
  State<ArTryOnScreen> createState() => _ArTryOnScreenState();
}

class _ArTryOnScreenState extends State<ArTryOnScreen> {
  late final String _viewType;
  late final String _containerId;
  bool _isReady = false;
  bool _hasError = false;
  String? _errorMessage;
  String _status = 'Extracting jewelry from product image…';

  @override
  void initState() {
    super.initState();
    _viewType = 'ar_view_${DateTime.now().millisecondsSinceEpoch}';
    _containerId = 'ar_container_${DateTime.now().millisecondsSinceEpoch}';
    ArWebBridge.registerViewFactory(_viewType, _containerId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!kIsWeb) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Web AR requires a browser target.';
      });
      return;
    }

    try {
      await ArWebBridge.ensureScriptsLoaded();
      await Future.delayed(const Duration(milliseconds: 120));

      final overlayUrl = await ArJewelryExtractorService.extractOverlay(
            widget.productImageUrl,
            widget.productCategory,
          ) ??
          widget.productImageUrl;

      if (!mounted) return;
      setState(() => _status = 'Starting webcam and landmark tracking…');

      await ArWebBridge.initPipeline(
        _containerId,
        widget.productCategory,
        overlayUrl,
      );

      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      ArWebBridge.stopPipeline(_containerId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.productName ?? widget.productCategory;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('AR Try-On — $title'),
        backgroundColor: const Color(0xFF0B1C2D),
      ),
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage ?? 'AR failed to start.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                HtmlElementView(viewType: _viewType),
                if (!_isReady)
                  ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFFFFD700)),
                          const SizedBox(height: 16),
                          Text(_status, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.productCategory.toLowerCase().contains('earring')
                          ? 'Earrings locked to ear landmarks 234 & 454 with lobe dangle offset.'
                          : 'Necklace/choker anchored from chin landmark 152 with depth scaling.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
