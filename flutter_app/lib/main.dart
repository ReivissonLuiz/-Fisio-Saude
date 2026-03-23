/// main.dart
/// Ponto de entrada do app +Físio +Saúde.
/// Configura o tema e as rotas de navegação.

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password/forgot_step1_screen.dart';
import 'screens/forgot_password/forgot_step2_screen.dart';
import 'screens/forgot_password/forgot_step3_screen.dart';
import 'screens/register/profile_selection_screen.dart';
import 'screens/register/patient_register_screen.dart';
import 'screens/register/professional_register_screen.dart';

void main() {
  runApp(const FisioSaudeApp());
}

class FisioSaudeApp extends StatelessWidget {
  const FisioSaudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '+Físio +Saúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-step1': (context) => const ForgotStep1Screen(),
        '/forgot-step2': (context) => const ForgotStep2Screen(),
        '/forgot-step3': (context) => const ForgotStep3Screen(),
        '/profile-selection': (context) => const ProfileSelectionScreen(),
        '/register-patient': (context) => const PatientRegisterScreen(),
        '/register-professional': (context) => const ProfessionalRegisterScreen(),
      },
    );
  }
}
