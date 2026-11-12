import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/main_navigation.dart';

import 'package:google_fonts/google_fonts.dart';

class HisaabBrabarApp extends StatelessWidget {
  const HisaabBrabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hisaab Brabar',
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),

      builder: (context, child) {
        return DefaultTextStyle(
          style: GoogleFonts.manrope(
            color: AppColors.textPrimary,
            decoration: TextDecoration.none,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
