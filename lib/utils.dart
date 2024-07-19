
import "dart:math";

import "package:camera/camera.dart";
import "package:flutter/foundation.dart";
import "package:google_mlkit_face_detection/google_mlkit_face_detection.dart";
import "package:image/image.dart" as img_lib;

import "camera_data.dart";

class Utils {
  static Future<img_lib.Image?> imageFromCameraImage(CameraData myData) async {
    final image = myData.image;
    final dir = myData.direction;
    try {
      img_lib.Image img;
      switch (image.format.group) {
        case ImageFormatGroup.yuv420:
          img = imageFromYUV420(image, dir);
          break;
        case ImageFormatGroup.bgra8888:
          img = imageFromBGRA8888(image);
          break;
        default:
          return null;
      }
      return img;
    } catch (e) {
      debugPrint("Error converting imageFromCameraImage : ${e.toString()}");
    }
    return null;
  }

  static Future<Uint8List?> uInt8ListFromImgLibImage(img_lib.Image image) async{
    try {

      // img_lib.Image imgTwo = img_lib.copyResize(image,width: 320, height: 240);
      // print('imageeeeeeeee is : ${imgTwo.width} ${imgTwo.height}');
      return img_lib.encodePng(image);
    } catch (e) {
      if (kDebugMode) {
        print(">>>>>>>>>>>> ERROR:$e");
      }
    }
    return null;
  }

  static Future<img_lib.Image?> imageFromCameraImageOnSeparateIsolate (CameraImage image, CameraLensDirection lensDirection) async{
    img_lib.Image? img = await compute(imageFromCameraImage, CameraData(image, lensDirection));
    debugPrint('img is here :: width : ${img?.width} and height : ${img?.height} ');
    return img;
  }

  static Future<Uint8List?> uInt8ListFromImgLibImageOnSeparateIsolate (img_lib.Image image) async{
    Uint8List? bytes = await compute(uInt8ListFromImgLibImage, image);
    debugPrint('uInt8list is here :: $bytes ');
    return bytes;
  }


  static img_lib.Image imageFromYUV420(CameraImage image, CameraLensDirection dir) {
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 0;
    final img = img_lib.Image(width: image.width, height: image.height);
    for (final p in img) {
      final x = p.x;
      final y = p.y;
      final uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final index = y * uvRowStride +
          x; // Use the row stride instead of the image width as some devices pad the image data, and in those cases the image width != bytesPerRow. Using width will give you a distorted image.
      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];
      p.r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255).toInt();
      p.g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255).toInt();
      p.b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255).toInt();
    }
    // image is rotated when converted so based on camera rotate it back to original angle
    // image from front camera is also flipped or mirrored so we again flip it
    var img1 =
        (dir == CameraLensDirection.front) ? img_lib.copyRotate(img, angle: -90) : img_lib.copyRotate(img, angle: 90);
    var img2 = (dir == CameraLensDirection.front) ? img_lib.flipHorizontal(img1) : img1;
    return img2;
  }

  static img_lib.Image imageFromBGRA8888(CameraImage image) {
    return img_lib.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img_lib.ChannelOrder.bgra,
    );
  }

  static double euclideanDistance(List e1, List e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }

  static String compare(List<dynamic> faceOneEmb, Map data) {
      double currDist = 0.0;
      String predRes = "NOT RECOGNIZED";
      for (String label in data.keys) {
        currDist = euclideanDistance(data[label], faceOneEmb);
        // 1.0 is my threshold value if value is greater then 0 and less then 1.0 then face is recognized
        if (currDist <= 1.0) {
          predRes = label;
        }
      }
      debugPrint(" compare result :: $currDist $predRes");
      return predRes;
  }

  static Float32List imageToByteListFloat32(
      img_lib.Image image, int inputSize, double mean, double std) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - mean) / std;
        buffer[pixelIndex++] = (pixel.g - mean) / std;
        buffer[pixelIndex++] = (pixel.b - mean) / std;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }
}
