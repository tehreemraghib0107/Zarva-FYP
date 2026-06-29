import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'ar_jewelry_screen.dart';

/// Real-time jewelry overlay painter — earlobe / neck landmark tracking with smoothing.
class JewelryTryOnPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final int sensorRotation;
  final DecodedJewelryAsset? jewelryAsset;
  final String category;

  static Offset? _lastLeftEar;
  static Offset? _lastRightEar;
  static Offset? _lastNeck;
  static double _lastFaceWidth = 0.0;

  static void resetSmoothing() {
    _lastLeftEar = null;
    _lastRightEar = null;
    _lastNeck = null;
    _lastFaceWidth = 0.0;
  }

  JewelryTryOnPainter({
    required this.faces,
    required this.imageSize,
    required this.sensorRotation,
    required this.jewelryAsset,
    required this.category,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty) return;

    final face = faces.first;
    final bool isRotated = sensorRotation == 90 || sensorRotation == 270;
    final double inputWidth = isRotated ? imageSize.height : imageSize.width;
    final double inputHeight = isRotated ? imageSize.width : imageSize.height;

    final double scaleX = size.width / inputWidth;
    final double scaleY = size.height / inputHeight;
    final double scale = math.max(scaleX, scaleY);
    final double offsetX = (size.width - (inputWidth * scale)) / 2;
    final double offsetY = (size.height - (inputHeight * scale)) / 2;

    Offset mapPoint(math.Point<int> point) {
      return Offset(
        size.width - (point.x * scale) - offsetX,
        point.y * scale + offsetY,
      );
    }

    final double rollAngle = (face.headEulerAngleZ ?? 0.0) * math.pi / 180.0;
    final rawFaceWidth = face.boundingBox.width * scale;
    final rawFaceHeight = face.boundingBox.height * scale;

    _lastFaceWidth = _lastFaceWidth == 0.0
        ? rawFaceWidth
        : ui.lerpDouble(_lastFaceWidth, rawFaceWidth, 0.25)!;
    final double faceWidth = _lastFaceWidth;
    final double faceHeight = faceWidth * (rawFaceHeight / rawFaceWidth);

    // Map face center correctly to handle sensor rotation
    final double rawCenterX = face.boundingBox.left + face.boundingBox.width / 2;
    final double rawCenterY = face.boundingBox.top + face.boundingBox.height / 2;
    final Offset faceCenterMapped = mapPoint(math.Point(rawCenterX.toInt(), rawCenterY.toInt()));
    final double faceCenterX = faceCenterMapped.dx;
    final double faceCenterY = faceCenterMapped.dy;

    final String catLower = category.toLowerCase();

    final leftEarLandmark = face.landmarks[FaceLandmarkType.leftEar];
    final rightEarLandmark = face.landmarks[FaceLandmarkType.rightEar];

    Offset leftEarRaw = Offset.zero;
    Offset rightEarRaw = Offset.zero;

    final faceContour = face.contours[FaceContourType.face];

    if (catLower.contains('earring')) {
      // Use ML Kit ear landmarks directly for accurate earlobe placement
      if (leftEarLandmark != null && rightEarLandmark != null) {
        leftEarRaw = mapPoint(leftEarLandmark.position);
        rightEarRaw = mapPoint(rightEarLandmark.position);

        // Offset slightly downward to place at earlobe (not at ear top)
        final double lobeOffsetY = faceHeight * 0.08;
        leftEarRaw += Offset(0, lobeOffsetY);
        rightEarRaw += Offset(0, lobeOffsetY);
      } else if (faceContour != null && faceContour.points.length >= 36) {
        // Fallback: use face contour points to estimate ear positions
        // Points 0-4 are roughly the right side of face (viewer's left)
        // Points 31-35 are roughly the left side of face (viewer's right)
        final ptRightEar = mapPoint(faceContour.points[2]); // Viewer's left cheek area
        final ptLeftEar = mapPoint(faceContour.points[33]); // Viewer's right cheek area

        final dirRight = ptRightEar - faceCenterMapped;
        final dirLeft = ptLeftEar - faceCenterMapped;

        // Offset outward from face center and downward for earlobe
        final double outwardOffset = faceWidth * 0.18;
        final double downwardOffset = faceHeight * 0.06;

        rightEarRaw = ptRightEar + Offset(dirRight.dx.sign * outwardOffset, downwardOffset);
        leftEarRaw = ptLeftEar + Offset(dirLeft.dx.sign * outwardOffset, downwardOffset);
      } else {
        // Final fallback: use bounding box-based estimation
        leftEarRaw = Offset(faceCenterX - faceWidth * 0.42, faceCenterY + faceHeight * 0.08);
        rightEarRaw = Offset(faceCenterX + faceWidth * 0.42, faceCenterY + faceHeight * 0.08);
      }

      _lastLeftEar = _lastLeftEar == null
          ? leftEarRaw
          : Offset.lerp(_lastLeftEar, leftEarRaw, 0.25);
      _lastRightEar = _lastRightEar == null
          ? rightEarRaw
          : Offset.lerp(_lastRightEar, rightEarRaw, 0.25);

      // Find Chin Tip (equivalent to Landmark 152) and Forehead Tip (equivalent to Landmark 10)
      Offset chin;
      Offset forehead;
      if (faceContour != null && faceContour.points.isNotEmpty) {
        var lowestPoint = faceContour.points.first;
        var highestPoint = faceContour.points.first;
        for (final pt in faceContour.points) {
          if (pt.y > lowestPoint.y) {
            lowestPoint = pt;
          }
          if (pt.y < highestPoint.y) {
            highestPoint = pt;
          }
        }
        chin = mapPoint(lowestPoint);
        forehead = mapPoint(highestPoint);
      } else {
        chin = Offset(faceCenterX, faceCenterY + faceHeight * 0.5);
        forehead = Offset(faceCenterX, faceCenterY - faceHeight * 0.5);
      }

      // Compute head scale baseline (Chin to Forehead)
      final double headScale = (chin - forehead).distance;
      // Scale height of the single cropped earring directly proportional to this baseline
      final double earringHeight = headScale * 0.20;

      _drawEarring(canvas, _lastLeftEar!, rollAngle, earringHeight, false);
      _drawEarring(canvas, _lastRightEar!, rollAngle, earringHeight, true);
    } else {
      // Find Chin Tip (equivalent to Landmark 152) using contour if available
      Offset chin;
      Offset jawL;
      Offset jawR;
      if (faceContour != null && faceContour.points.isNotEmpty) {
        var lowestPoint = faceContour.points.first;
        for (final pt in faceContour.points) {
          if (pt.y > lowestPoint.y) {
            lowestPoint = pt;
          }
        }
        chin = mapPoint(lowestPoint);

        // Outer jaw contours: Map points 9 and 27 for left/right jaw boundaries
        if (faceContour.points.length >= 36) {
          jawL = mapPoint(faceContour.points[9]);
          jawR = mapPoint(faceContour.points[27]);
        } else {
          jawL = Offset(faceCenterX - faceWidth * 0.35, faceCenterY + faceHeight * 0.15);
          jawR = Offset(faceCenterX + faceWidth * 0.35, faceCenterY + faceHeight * 0.15);
        }
      } else {
        chin = Offset(faceCenterX, face.boundingBox.bottom * scale + offsetY);
        jawL = Offset(faceCenterX - faceWidth * 0.35, faceCenterY + faceHeight * 0.15);
        jawR = Offset(faceCenterX + faceWidth * 0.35, faceCenterY + faceHeight * 0.15);
      }

      // Estimate shoulders relative to jaw to define the neck boundaries
      final Offset shL = Offset(jawL.dx, jawL.dy + faceHeight * 0.8);
      final Offset shR = Offset(jawR.dx, jawR.dy + faceHeight * 0.8);

      // Compute the dynamic width of the actual neck base region (interpolated at 45% between jaw and shoulder)
      const double tNeck = 0.45;
      final Offset neckBaseL = Offset.lerp(jawL, shL, tNeck)!;
      final Offset neckBaseR = Offset.lerp(jawR, shR, tNeck)!;
      final double neckWidth = (neckBaseR - neckBaseL).distance;

      // Estimate shoulder base center
      final Offset shoulderCenter = Offset((shL.dx + shR.dx) / 2, (shL.dy + shR.dy) / 2);
      final Offset neckVector = shoulderCenter - chin;

      // Tight static offset upward toward throat for chokers, lower on collarbone plane for necklaces
      final double t = catLower.contains('choker') ? 0.22 : 0.68;
      final Offset neckRaw = chin + neckVector * t;

      _lastNeck = _lastNeck == null ? neckRaw : Offset.lerp(_lastNeck, neckRaw, 0.25);

      // Scale drawing width to exactly 1.15x the computed neck base width
      final double necklaceWidth = neckWidth * 1.15;
      _drawNecklace(canvas, _lastNeck!, rollAngle, necklaceWidth);
    }
  }

  void _drawEarring(Canvas canvas, Offset position, double rollAngle, double height, bool isRight) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rollAngle);

    if (jewelryAsset != null) {
      final double earringHeight = height;
      final double earringWidth = earringHeight * jewelryAsset!.aspectRatio;
      
      if (isRight) {
        canvas.scale(-1, 1);
      }

      canvas.drawImageRect(
        jewelryAsset!.image,
        jewelryAsset!.bounds,
        Rect.fromLTWH(-earringWidth / 2, 0, earringWidth, earringHeight),
        Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.high,
      );
    }
    canvas.restore();
  }

  void _drawNecklace(Canvas canvas, Offset position, double rollAngle, double width) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rollAngle);

    if (jewelryAsset != null) {
      final height = width / jewelryAsset!.aspectRatio;
      canvas.drawImageRect(
        jewelryAsset!.image,
        jewelryAsset!.bounds,
        Rect.fromLTWH(-width / 2, -height * 0.3, width, height),
        Paint()
          ..isAntiAlias = true
          ..filterQuality = ui.FilterQuality.high,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant JewelryTryOnPainter oldDelegate) => true;
}
