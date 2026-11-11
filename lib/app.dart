import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/screens/home_screen.dart';

class HisaabBrabarApp extends StatelessWidget {
  const HisaabBrabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hisaab brabar',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
