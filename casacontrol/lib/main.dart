import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    demoMode: const bool.fromEnvironment('DEMO_MODE'),
  );
  controller.start();
  runApp(CasaControlApp(controller: controller));
}

class CasaControlApp extends StatelessWidget {
  const CasaControlApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CasaControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6FD8),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6FD8),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
