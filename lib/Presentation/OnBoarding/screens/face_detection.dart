import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool isFrontCamera;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.green;

    for (final face in faces) {
      Rect rect = face.boundingBox;

      // Flip for front camera if needed
      if (isFrontCamera) {
        rect = Rect.fromLTRB(
          imageSize.width - rect.right,
          rect.top,
          imageSize.width - rect.left,
          rect.bottom,
        );
      }

      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;

      final scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
