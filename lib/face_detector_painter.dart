import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorPainter extends CustomPainter{
  FaceDetectorPainter(this.facesData, {required this.faces, required this.imageSize});
  final List<Face> faces;
  final Size imageSize;
  final Map<String, Face> facesData;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    facesData.forEach((key, value) {
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;
      debugPrint("scale x : $scaleX and scale y : $scaleY");
      double x, y, w, h;
      x = ((value.boundingBox.left) * scaleX);
      y = ((value.boundingBox.top) * scaleY);
      w = (value.boundingBox.width * scaleX);
      h = (value.boundingBox.height * scaleY);
      final Rect rect = Rect.fromLTWH(x, y, w, h);
      debugPrint('Face rectangle will be painted at rect : $rect');
      canvas.drawRect(rect, paint);
      // text layout
      TextSpan span = TextSpan(
          style: TextStyle(color: Colors.orange[300], fontSize: 15),
          text: key);
      TextPainter textPainter = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(
              value.boundingBox.left.toDouble()* scaleX ,
              (value.boundingBox.top.toDouble() - 10) * scaleY));
    });
    // for(final Face face in faces){
    //   final scaleX = size.width / imageSize.width;
    //   final scaleY = size.height / imageSize.height;
    //   debugPrint("scale x : $scaleX and scale y : $scaleY");
    //   double x, y, w, h;
    //   x = ((face.boundingBox.left) * scaleX);
    //   y = ((face.boundingBox.top) * scaleY);
    //   w = (face.boundingBox.width * scaleX);
    //   h = (face.boundingBox.height * scaleY);
    //   final Rect rect = Rect.fromLTWH(x, y, w, h);
    //   debugPrint('Face rectangle will be painted at rect : $rect');
    //   canvas.drawRect(rect, paint);
    //   // text layout
    //   TextSpan span = TextSpan(
    //       style: TextStyle(color: Colors.orange[300], fontSize: 15),
    //       text: "Hi there");
    //   TextPainter textPainter = TextPainter(
    //       text: span,
    //       textAlign: TextAlign.left,
    //       textDirection: TextDirection.ltr);
    //   textPainter.layout();
    //   textPainter.paint(
    //       canvas,
    //       Offset(
    //            face.boundingBox.left.toDouble()* scaleX ,
    //           (face.boundingBox.top.toDouble() - 10) * scaleY));
    //
    // }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
  
}