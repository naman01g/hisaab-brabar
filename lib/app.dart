import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/main_navigation.dart';
import 'features/auth/presentation/screens/auth_screen.dart';

class HisaabBrabarApp extends StatelessWidget {
  const HisaabBrabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hisaab Brabar',
      theme: AppTheme.lightTheme,

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('Unable to check authentication status.'),
              ),
            );
          }

          if (snapshot.data != null) {
            return const MainNavigation();
          }

          return const AuthScreen();
        },
      ),

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
