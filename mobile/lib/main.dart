import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/setup/setup_wizard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: EndpageApp()));
}

class EndpageApp extends StatelessWidget {
  const EndpageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '熵析云枢',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        final user = authState.user;
        if (user != null && user.needsSetup) {
          return const SetupWizardScreen();
        }
        return const HomeScreen();
    }
  }
}
