/// Auth Gate
/// Checks authentication state and routes to appropriate screen

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user is signed in
        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // User is signed in, go to home screen
          return const HomeScreen();
        } else {
          // User is not signed in, go to login screen
          return const LoginScreen();
        }
      },
    );
  }
}
