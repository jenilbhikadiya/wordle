import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const WordleCloneApp(),
  );
}

class WordleCloneApp extends StatelessWidget {
  const WordleCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini Wordle',
      theme: ThemeData(primarySwatch: Colors.green),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true, // ✅ Required for DevicePreview
      builder: DevicePreview.appBuilder, // ✅ Integrates the preview
    );
  }
}
