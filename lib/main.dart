import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
// Force landscape orientation for all screens
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indie Dungeon Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'PressStart2P',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5A2D0C),
        ),
        scaffoldBackgroundColor: const Color(0xFF1B1B1B),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 32,
            color: Color(0xFFE2B659),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            color: Color(0xFFF5F5F5),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}