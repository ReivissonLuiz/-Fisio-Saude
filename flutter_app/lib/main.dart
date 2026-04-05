/// main.dart
/// Ponto de entrada do app +Físio +Saúde.
/// Configura tema, rotas e listener global de autenticação (recovery de senha).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password/forgot_step1_screen.dart';
import 'screens/forgot_password/reset_password_screen.dart';
import 'screens/register/profile_selection_screen.dart';
import 'screens/register/patient_register_screen.dart';
import 'screens/register/professional_register_screen.dart';
import 'screens/register/register_success_screen.dart';
import 'screens/register/admin_register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase antes de qualquer widget
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const FisioSaudeApp());
}

// Chave global para navegar a partir de qualquer lugar no app
final _navigatorKey = GlobalKey<NavigatorState>();

class FisioSaudeApp extends StatefulWidget {
  const FisioSaudeApp({super.key});

  @override
  State<FisioSaudeApp> createState() => _FisioSaudeAppState();
}

class _FisioSaudeAppState extends State<FisioSaudeApp> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Ouve eventos globais de autenticação do Supabase
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Quando o usuário clica no link de recuperação do e-mail,
      // o Supabase emite este evento com type=recovery
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/reset-password',
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '+Físio +Saúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: _navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-step1': (context) => const ForgotStep1Screen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/profile-selection': (context) => const ProfileSelectionScreen(),
        '/register-patient': (context) => const PatientRegisterScreen(),
        '/register-professional': (context) =>
            const ProfessionalRegisterScreen(),
        '/register-admin': (context) => const AdminRegisterScreen(),
        '/register-success': (context) {
          final tipo =
              ModalRoute.of(context)!.settings.arguments as String? ??
                  'Paciente';
          return RegisterSuccessScreen(tipoConta: tipo);
        },
      },
    );
  }
}
