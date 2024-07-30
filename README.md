# Face Detection and Recognition in Flutter

Developed a Flutter project for face detection and recognition using packages including 
- [tflite_flutter](https://pub.dev/packages/tflite_flutter) 
- [path_provider](https://pub.dev/packages/path_provider)
- [camera](https://pub.dev/packages/camera)
- [image](https://pub.dev/packages/image)
- [google_mlkit_face_detection](https://pub.dev/packages/google_mlkit_face_detection)
- [image_picker](https://pub.dev/packages/image_picker) 

The app supports real-time face detection from the camera and image recognition from the gallery.

## Getting Started

To get started add the following packages mentioned above. 
I have set my min sdk version to 26 in my app/build.gradle
```
defaultConfig {
        // your other config
        minSdkVersion 26
    }
```
I have also updated my kotlin version in android/settings.gradle
```
plugins {
    id "org.jetbrains.kotlin.android" version "1.9.10" apply false
}
```

if you have any other issues with your project. Please do check the this project files to follow every necessary things. I have used model of tflite which you can see in project root directory under assets folder. This is quite a nice model but is not very precise. You can use it for testing purpose.

First of all you have to load tflite model in the init state
```
Future loadModel() async {
    try {
      final gpuDelegateV2 = GpuDelegateV2(
          options: GpuDelegateOptionsV2(
        isPrecisionLossAllowed: false,
      ));

      var interpreterOptions = InterpreterOptions()..addDelegate(gpuDelegateV2);
      interpreter = await Interpreter.fromAsset('assets/face_recog_model.tflite',
          options: interpreterOptions);
    } on Exception {
      debugPrint('Failed to load model.');
    }
  }
```

Then you have to initialize the camera this way

```
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
```

I have called the getCamera method to get the back camera as default camera

```
// Get specific camera based on its lens direction
  CameraDescription getCamera(CameraLensDirection dir) {
    return cameraDescriptionList
        .firstWhere((CameraDescription cameraDescription) => cameraDescription.lensDirection == dir);
  }
```
We have to get the camera preview image size as the camera image size and mobile app screen size is not same . When we detect image then we will be getting detected faces Rect information but this information will be according to camera preview image size and we have to scale this according to our mobile app screen size

```
// inside camera initialization
cameraImageSize =
            Size(_cameraController?.value.previewSize?.width ?? 0, _cameraController?.value.previewSize?.height ?? 0);
```

When camera is finally initialized then we will call detectFacesFromCamera method. To use image for processing we cannot directly use CameraImage from stream. We have to convert cameraImage into Image(From image package) and then we can easily convert them into File and process them

```
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

```

When we get the crop face then we will call the recognize method which can recognize them image if it is saved in data and create face embedding which can be used to compare two faces

```
Future<void> recognize(img_lib.Image img) async {
    List input = Utils.imageToByteListFloat32(img, 112, 128, 128);
    input = input.reshape([1, 112, 112, 3]);
    // List output = Float32List(1 * 192).reshape([1, 192]);
    List output = Float32List(1 * 128).reshape([1, 128]);
    debugPrint("output before : $output");
    interpreter?.run(input, output);
    // output = output.reshape([192]);
    output = output.reshape([128]);
      faceEmb = List.from(output);
    // data['kala'] = e1;
    debugPrint("output after : $output : $faceEmb");
  }
```

And we can compare the data with the current face embedding that we get in the recognize method as face_emb

```
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
```

