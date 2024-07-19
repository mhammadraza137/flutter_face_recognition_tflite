import 'dart:convert';
import 'dart:io';
import 'package:face_recognition_tflite/face_detector_painter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img_lib;
import 'package:camera/camera.dart';
import 'package:face_recognition_tflite/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool isCameraInitialized = false;
  AppLifecycleListener? appLifecycleListener;
  Interpreter? interpreter;
  List<CameraDescription> cameraDescriptionList = [];
  CameraDescription? selectedCameraDescription;
  CameraController? _cameraController;
  bool _isDetecting = false;
  img_lib.Image? imgLibImage;
  File? showAbleCameraImage;
  File? cropFaceImage;
  File? jsonFile;
  Uint8List? bytes;
  Size? cameraImageSize;
  final FaceDetectorOptions faceDetectorOptions = FaceDetectorOptions();
  late FaceDetector faceDetector;
  List<Face> faces = [];
  List faceEmb = [];
  dynamic data = {};
  double threshold = 1.0;
  Map<String, Face> facesData = {};
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadModel();
    getJsonFile();
    faceDetector = FaceDetector(options: faceDetectorOptions);
    initializeCamera();
    initAppLifeCycleListener();
  }

  @override
  void dispose() {
    super.dispose();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    appLifecycleListener?.dispose();
    _nameCtrl.dispose();
  }

  // initialize camera
  Future<void> initializeCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    isCameraInitialized = false;
    if (mounted) {
      setState(() {});
    }
    cameraDescriptionList = await availableCameras();
    // will get camera only if there is not selected camera (for the first time)
    selectedCameraDescription ??= getCamera(CameraLensDirection.back);
    debugPrint("Selected Camera is  : ${selectedCameraDescription?.lensDirection}");
    if (selectedCameraDescription != null) {
      _cameraController = CameraController(selectedCameraDescription!, ResolutionPreset.low);
      await _cameraController!.initialize().then((value) {
        cameraImageSize =
            Size(_cameraController?.value.previewSize?.width ?? 0, _cameraController?.value.previewSize?.height ?? 0);
        debugPrint("camera is initialized with dimensions as width : ${cameraImageSize?.width} "
            "and height : ${cameraImageSize?.height}");
        if (!mounted) {
          debugPrint("State object is not in a tree mounted($mounted)");
          return;
        } else {
          setState(() {
            isCameraInitialized = true;
          });
          detectFacesFromCamera();
        }
      }).catchError((Object e) {
        if (e is CameraException) {
          switch (e.code) {
            case "CameraAccessDenied":
              debugPrint("Camera access denied");
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Camera access Denied")));
            default:
              debugPrint('Camera exception : ${e.description}');
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Camera exception : ${e.description}')));
          }
        } else {
          debugPrint("Exception occurred : ${e.toString()}");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exception occurred : ${e.toString()}")));
        }
      });
    }
  }

  // handle app state when app state is paused or resumed
  void initAppLifeCycleListener() {
    appLifecycleListener = AppLifecycleListener(
      binding: WidgetsBinding.instance,
      onStateChange: (state) {
        debugPrint('App lifecycle state is updated : ${state.name}');
      },
      onResume: () {
        initializeCamera();
      },
      onPause: () {
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          return;
        }
        _cameraController!.dispose();
      },
    );
  }

  // Get specific camera based on its lens direction
  CameraDescription getCamera(CameraLensDirection dir) {
    return cameraDescriptionList
        .firstWhere((CameraDescription cameraDescription) => cameraDescription.lensDirection == dir);
  }

  Future<void> detectFacesFromCamera() async {
    _cameraController?.startImageStream((image) async {
      if (_isDetecting) {
        return;
      }
      _isDetecting = true;
      imgLibImage = await Utils.imageFromCameraImageOnSeparateIsolate(image, selectedCameraDescription!.lensDirection);
      if (imgLibImage != null) {
        debugPrint(
            "camera image dimension : width : ${cameraImageSize?.width} ans height : ${cameraImageSize?.height}");
        debugPrint("img lib image dimension : width : ${imgLibImage?.width} and height : ${imgLibImage?.height}");
        if (cameraImageSize?.width != imgLibImage?.width || cameraImageSize?.height != imgLibImage?.height) {
          imgLibImage = img_lib.copyResize(imgLibImage!,
              width: cameraImageSize!.width.toInt(), height: cameraImageSize!.height.toInt());
          debugPrint(
              "img lib image updated dimensions : width : ${imgLibImage?.width} : and height : ${imgLibImage?.height}");
        }
        bytes = await Utils.uInt8ListFromImgLibImageOnSeparateIsolate(imgLibImage!);
      } else {
        debugPrint("img lib image is null");
      }
      Directory docDir = await getApplicationDocumentsDirectory();
      showAbleCameraImage = File('${docDir.path}/${DateTime.now().millisecondsSinceEpoch}');
      showAbleCameraImage!.writeAsBytesSync(bytes!);
      //
      faces = await faceDetector.processImage(InputImage.fromFile(showAbleCameraImage!));
      debugPrint("Faces length is : ${faces.length}");
      for (var face in faces) {
        debugPrint("Face rect is : ${face.boundingBox}");
      }
      //
      if (faces.isNotEmpty && mounted) {
        debugPrint("please show dialog");
        Face firstFace = faces.first;
        int x, y, w, h;
        x = (firstFace.boundingBox.left).toInt();
        y = (firstFace.boundingBox.top).toInt();
        w = (firstFace.boundingBox.width).toInt();
        h = (firstFace.boundingBox.height).toInt();
        debugPrint("face crop rect is : $x $y $w $h");
        img_lib.Image cropFace = img_lib.copyCrop(imgLibImage!, x: x, y: y, width: w, height: h);
        cropFace = img_lib.copyResizeCropSquare(cropFace, size: 112);
        Uint8List? cropFaceBytes = await Utils.uInt8ListFromImgLibImageOnSeparateIsolate(cropFace);
        Directory docDir = await getApplicationDocumentsDirectory();
        cropFaceImage = File('${docDir.path}/${DateTime.now().millisecondsSinceEpoch}');
        cropFaceImage!.writeAsBytesSync(cropFaceBytes!);
        await recognize(cropFace);
        String nameOfRecognizedPerson = Utils.compare(faceEmb, data);
        facesData.clear();
        facesData[nameOfRecognizedPerson] = firstFace;
      } else {
        facesData.clear();
      }
      _isDetecting = false;
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> recognize(img_lib.Image img) async {
    List input = Utils.imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    List output = Float32List(1 * 192).reshape([1, 192]);
    // List output = Float32List(1 * 128).reshape([1, 128]);
    debugPrint("output before : $output");
    interpreter?.run(input, output);
    output = output.reshape([192]);
    // output = output.reshape([128]);
      faceEmb = List.from(output);
    // data['kala'] = e1;
    debugPrint("output after : $output : $faceEmb");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
      ),
      body: !isCameraInitialized
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: FaceDetectorPainter(facesData,faces: faces, imageSize: cameraImageSize!),
                  ),
                ),
                if (showAbleCameraImage != null)
                  Positioned(
                    top: 100,
                    left: 20,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      // color: Colors.red,
                      child: Image.file(
                        showAbleCameraImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "fab1",
            onPressed: saveFace,
            child: const Icon(Icons.save),
          ),
          const SizedBox(
            height: 10,
          ),
          FloatingActionButton(
            heroTag: "fab2",
            onPressed: _toggleCamera,
            child: Icon(selectedCameraDescription?.lensDirection == CameraLensDirection.back
                ? Icons.photo_camera_back
                : Icons.camera_front),
          )
        ],
      ),
    );
  }

  Future<void> _toggleCamera() async {
    if (selectedCameraDescription?.lensDirection == CameraLensDirection.back) {
      selectedCameraDescription = getCamera(CameraLensDirection.front);
    } else {
      selectedCameraDescription = getCamera(CameraLensDirection.back);
    }
    await _cameraController?.stopImageStream();
    _cameraController?.dispose();
    initializeCamera();
  }

  Future loadModel() async {
    try {
      final gpuDelegateV2 = GpuDelegateV2(
          options: GpuDelegateOptionsV2(
        isPrecisionLossAllowed: false,
      ));

      var interpreterOptions = InterpreterOptions()..addDelegate(gpuDelegateV2);
      interpreter = await Interpreter.fromAsset('assets/mobile_face_net.tflite', options: interpreterOptions);
    } on Exception {
      debugPrint('Failed to load model.');
    }
  }

  void getJsonFile() async {
    final tempDir = await getApplicationDocumentsDirectory();
    String embPath = '${tempDir.path}/emb.json';
    jsonFile = File(embPath);
    if (jsonFile!.existsSync()) data = json.decode(jsonFile!.readAsStringSync());
    debugPrint("data is :: $data");
  }

  void saveFace() async{
    if(cropFaceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No face is detected at moment")));
      return;
    }
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(cropFaceImage!),
              const SizedBox(height: 20,),
              TextFormField(
                controller: _nameCtrl,
              ),
              const SizedBox(height: 20,),
              ElevatedButton(onPressed: (){
                data[_nameCtrl.text.trim()] = faceEmb;
                jsonFile!.writeAsStringSync(json.encode(data));
                _nameCtrl.clear();
                getJsonFile();
                Navigator.pop(context);
              }, child: const Text('Save Face'))
            ],

          ),
        );
      },
    );
  }
}
