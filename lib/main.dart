import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';

void main() {
  runApp(const ProviderScope(child: SolaceApp()));
}

class SolaceApp extends StatelessWidget {
  const SolaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solace',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const RootRouter(),
    );
  }
}

class RootRouter extends ConsumerWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // avoids a login screen flash while the saved session loads
    if (authState.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return authState.isSignedIn ? const FeedScreen() : const LoginScreen();
  }
}