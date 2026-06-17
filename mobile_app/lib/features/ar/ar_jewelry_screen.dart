import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/ar_jewelry_extractor_service.dart';
import 'jewelry_try_on_painter.dart';

/// Native mobile AR try-on — camera stream + ML Kit face landmarks + custom painter.
class ARJewelryScreen extends StatefulWidget {
  final String productCategory;
  final String productImageUrl;
  final String? productName;

  const ARJewelryScreen({
    super.key,
    required this.productCategory,
    required this.productImageUrl,
    this.productName,
  });

  @override
  State<ARJewelryScreen> createState() => _ARJewelryScreenState();
}

class _ARJewelryScreenState extends State<ARJewelryScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isProcessing = false;
  bool _isCameraInitializing = true;
  String _statusText = 'Initializing Camera...';

  List<Face> _detectedFaces = [];
  Size? _imageSize;
  int _sensorRotation = 0;

  DecodedJewelryAsset? _jewelryAsset;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    JewelryTryOnPainter.resetSmoothing();
    _initializeFaceDetector();
    _loadJewelryImage();
    _requestPermissionsAndInitCamera();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: false,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> _loadJewelryImage() async {
    setState(() => _isLoadingImage = true);

    try {
      String? processedUrl;
      if (widget.productImageUrl.isNotEmpty) {
        processedUrl = await ArJewelryExtractorService.extractOverlay(
          widget.productImageUrl,
          widget.productCategory,
        );
      }

      final pathOrUrl = processedUrl ?? (widget.productImageUrl.isNotEmpty
          ? widget.productImageUrl
          : (widget.productCategory.toLowerCase().contains('earring')
              ? 'assets/1E.png'
              : 'assets/2N.png'));

      final decoded = await _loadImage(pathOrUrl);
      final bounds = await _findNonTransparentBounds(decoded);

      if (mounted) {
        setState(() {
          _jewelryAsset = DecodedJewelryAsset(image: decoded, bounds: bounds);
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load jewelry image: $e');
      if (mounted) {
        setState(() {
          _jewelryAsset = null;
          _isLoadingImage = false;
        });
      }
    }
  }

  Future<ui.Rect> _findNonTransparentBounds(ui.Image image) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      }
      
      final bytes = byteData.buffer.asUint8List();
      int minX = image.width;
      int maxX = 0;
      int minY = image.height;
      int maxY = 0;
      
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final index = (y * image.width + x) * 4;
          if (index + 3 < bytes.length) {
            final alpha = bytes[index + 3];
            if (alpha > 5) { // non-transparent threshold
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
      }
      
      if (maxX < minX || maxY < minY) {
        return ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      }
      
      return ui.Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      );
    } catch (e) {
      debugPrint("Error finding bounds: $e");
      return ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    }
  }

  Future<ui.Image> _loadImage(String pathOrUrl) async {
    final ImageProvider<Object> provider;
    if (pathOrUrl.startsWith('data:image')) {
      final base64String = pathOrUrl.split(',').last;
      provider = MemoryImage(base64Decode(base64String));
    } else if (pathOrUrl.startsWith('http')) {
      provider = NetworkImage(pathOrUrl);
    } else {
      provider = AssetImage(pathOrUrl);
    }

    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (exception, stackTrace) {
        completer.completeError(exception, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else if (mounted) {
      setState(() {
        _statusText = 'Camera permission denied.';
        _isCameraInitializing = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      await _cameraController!.startImageStream(_processCameraImage);
      setState(() {
        _isCameraInitializing = false;
        _statusText = 'Tracking face...';
      });
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _statusText = 'Camera initialization failed.';
          _isCameraInitializing = false;
        });
      }
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _faceDetector == null) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final rotation = InputImageRotationValue.fromRawValue(
            _cameraController!.description.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.yuv420;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      final faces = await _faceDetector!.processImage(inputImage);

      if (mounted) {
        setState(() {
          _detectedFaces = faces;
          _imageSize = imageSize;
          _sensorRotation = _cameraController!.description.sensorOrientation;
          _statusText =
              faces.isNotEmpty ? 'Tracking Active' : 'Searching for Face...';
        });
      }
    } catch (e) {
      debugPrint('Face detection error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      controller.startImageStream(_processCameraImage);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector?.close();
    _cameraController = null;
    _faceDetector = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.productName ?? widget.productCategory;

    if (_isCameraInitializing || _isLoadingImage) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(_statusText, style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.width * _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
          if (_detectedFaces.isNotEmpty && _imageSize != null)
            CustomPaint(
              painter: JewelryTryOnPainter(
                faces: _detectedFaces,
                imageSize: _imageSize!,
                sensorRotation: _sensorRotation,
                jewelryAsset: _jewelryAsset,
                category: widget.productCategory,
              ),
            ),
          Positioned(
            top: 40,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 48,
            left: 70,
            right: 70,
            child: Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${widget.productCategory} try-on — ${_statusText}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic cropped jewelry asset representation holding its calculated non-transparent bounds.
class DecodedJewelryAsset {
  final ui.Image image;
  final ui.Rect bounds;

  DecodedJewelryAsset({
    required this.image,
    required this.bounds,
  });

  double get intrinsicWidth => bounds.width;
  double get intrinsicHeight => bounds.height;
  double get aspectRatio => bounds.width / (bounds.height == 0 ? 1 : bounds.height);
}
