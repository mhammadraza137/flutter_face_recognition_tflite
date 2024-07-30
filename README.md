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

if you have any other issues with your project. Please do check the this project files to follow every necessary things.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
