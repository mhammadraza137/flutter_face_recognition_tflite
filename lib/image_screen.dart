import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:face_recognition_tflite/utils.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img_lib;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  State<ImageScreen> createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  File? firstImage, secondImage;
  Size? imageSize;
  final FaceDetectorOptions faceDetectorOptions = FaceDetectorOptions();
  late FaceDetector faceDetector;
  List<Face> faces = [];
  Interpreter? interpreter;
  List faceOneEmb = [];
  List faceTwoEmb = [];
  dynamic data = {};
  double threshold = 1.0;


  @override
  void initState() {
    super.initState();
    loadModel();
    faceDetector = FaceDetector(options: faceDetectorOptions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Screen'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      imageSize = Size(constraints.maxWidth, 200);
                      return Container(
                        width: imageSize?.width,
                        height: imageSize?.height,
                        decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 1)),
                        child: firstImage != null ? Image.file(firstImage!) : null,
                      );
                    }
                  ),
                  TextButton(onPressed: () => pickImage(isFirst: true), child: const Text("Pick Image"))
                ],
              )),
              Expanded(
                  child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      imageSize = Size(constraints.maxWidth, 200);
                      return Container(
                        width: imageSize?.width,
                        height: imageSize?.height,
                        decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 1)),
                        child: secondImage != null ? Image.file(secondImage!) : null,
                      );
                    }
                  ),
                  TextButton(onPressed: () => pickImage(isFirst: false), child: const Text("Pick Image"))
                ],
              )),
            ],
          ),
          const SizedBox(height: 20,),
          TextButton(onPressed:  compare, child: const Text('Compare'))
        ],
      ),
    );
  }

  Future<void> pickImage({required bool isFirst}) async {
    XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (isFirst) {
        firstImage = File(image.path);
      } else {
        secondImage = File(image.path);
      }
      setState(() {});
      // detect face from image and show
      faces.clear();
      faces = await faceDetector.processImage(InputImage.fromFilePath(image.path));
      debugPrint("Faces in image : ${faces.length}");
      if (faces.isNotEmpty) {
        Uint8List bytes;
        if (isFirst) {
          bytes = await firstImage!.readAsBytes();
        } else {
          bytes = await secondImage!.readAsBytes();
        }
        img_lib.Image? imgLibImage = img_lib.decodeImage(bytes);
        Face firstFace = faces.first;
        imgLibImage = img_lib.copyCrop(imgLibImage!,
            x: (firstFace.boundingBox.left.toInt() - 10),
            y: (firstFace.boundingBox.top.toInt() - 10),
            width: (firstFace.boundingBox.width.toInt() + 10),
            height: (firstFace.boundingBox.height.toInt() + 10));
        imgLibImage = img_lib.copyResize(imgLibImage, width: imageSize!.width.toInt(), height: imageSize!.height.toInt());
        Uint8List? cropFaceBytes  = await Utils.uInt8ListFromImgLibImageOnSeparateIsolate(imgLibImage);
        Directory docDir = await getApplicationDocumentsDirectory();
        File cropFaceImage = File('${docDir.path}/${DateTime.now().millisecondsSinceEpoch}');
        cropFaceImage.writeAsBytesSync(cropFaceBytes!);
        if(isFirst){
          firstImage = cropFaceImage;
        } else{
          secondImage = cropFaceImage;
        }
        setState(() {});
        // recognize face
        await recognize(imgLibImage, isFirst);
      }
    }
  }

  Future<void> recognize(img_lib.Image img, bool isFirst) async {
    List input = imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List output = Float32List(1 * 128).reshape([1, 128]);
    debugPrint("output before : $output");
     interpreter?.run(input, output);
    output = output.reshape([128]);
    if(isFirst){
      faceOneEmb = List.from(output);
    } else{
      faceTwoEmb = List.from(output);
    }
    // data['kala'] = e1;
    debugPrint("output after : $output : $faceOneEmb");
  }

  Float32List imageToByteListFloat32(
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
  String compare() {
    if(faceOneEmb.isNotEmpty && faceTwoEmb.isNotEmpty){
      double minDist = 999;
      double currDist = 0.0;
      String predRes = "NOT RECOGNIZED";
      // for (String label in data.keys) {
        currDist = euclideanDistance(faceOneEmb, faceTwoEmb);
        // if (currDist <= threshold && currDist < minDist) {
        minDist = currDist;
        // predRes = label;
        // }
      // }
      debugPrint(" compare result :: $minDist $predRes");
      if(currDist <= threshold ){
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Face is matched with a distance of $currDist")));
      } else{
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Face is not matched as  $currDist is greater then 1.0")));
      }
      return predRes;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Faces are empty")));
      return "emb is empty";
    }
  }
  double euclideanDistance(List e1, List e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += pow((e1[i] - e2[i]), 2);
    }
    return sqrt(sum);
  }


  Future loadModel() async {
    try {
      final gpuDelegateV2 = GpuDelegateV2(
          options: GpuDelegateOptionsV2(
            isPrecisionLossAllowed: false,));

      var interpreterOptions = InterpreterOptions()
        ..addDelegate(gpuDelegateV2);
      // interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite',
      //     options: interpreterOptions);
      interpreter = await Interpreter.fromAsset('assets/face_recog_model.tflite',
          options: interpreterOptions);
    } on Exception {
      debugPrint('Failed to load model.');
    }
  }
}
