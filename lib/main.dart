import 'package:face_recognition_tflite/image_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen()
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> buttons = [
      {
        "Camera": () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraScreen(),
            ))
      },
      {
        "Image": () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImageScreen(),
            ))
      },
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text("Main Screen"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          buttons.length,
              (index) {
            return Align(
                alignment: Alignment.center,
                child: ElevatedButton(onPressed: buttons[index].values.first, child: Text(buttons[index].keys.first)));
          },
        ),
      ),
    );
  }
}

