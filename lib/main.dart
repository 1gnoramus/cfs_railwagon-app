import 'package:cfs_railwagon/constants/theme_data.dart';
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const WagonApp());
}

class WagonApp extends StatelessWidget {
  const WagonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CF&S Kazakhstan - Вагонный контроль',
      debugShowCheckedModeBanner: false,
      theme: cfsTheme,
      home: const WelcomeScreen(),
    );
  }
}
