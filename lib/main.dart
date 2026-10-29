import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/feed_screen.dart';

Color _tint(Color seed, double lightness, double saturation) {
  return HSLColor.fromColor(seed)
      .withSaturation(saturation)
      .withLightness(lightness)
      .toColor();
}

ThemeData _buildTheme(Color seed, Brightness brightness) {
  if (brightness == Brightness.dark) {
    return ThemeData(
      colorSchemeSeed: seed,
      brightness: brightness,
      useMaterial3: true,
    );
  }
  final scheme = ColorScheme.fromSeed(seedColor: seed).copyWith(
    surface: _tint(seed, 0.95, 0.38),
    surfaceBright: _tint(seed, 0.975, 0.34),
    surfaceDim: _tint(seed, 0.90, 0.34),
    surfaceContainerLowest: _tint(seed, 0.985, 0.30),
    surfaceContainerLow: _tint(seed, 0.965, 0.34),
    surfaceContainer: _tint(seed, 0.94, 0.36),
    surfaceContainerHigh: _tint(seed, 0.92, 0.36),
    surfaceContainerHighest: _tint(seed, 0.90, 0.36),
  );
  return ThemeData(colorScheme: scheme, useMaterial3: true);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mode = await ThemeNotifier.loadSaved();
  final accent = await AccentNotifier.loadSaved();
  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(() => ThemeNotifier(mode)),
        accentProvider.overrideWith(() => AccentNotifier(accent)),
      ],
      child: const SolaceApp(),
    ),
  );
}

class SolaceApp extends ConsumerWidget {
  const SolaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final accent = ref.watch(accentProvider);

    return MaterialApp(
      title: 'Solace',
      theme: _buildTheme(accent.seed, Brightness.light),
      darkTheme: _buildTheme(accent.seed, Brightness.dark),
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
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

    if (authState.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return authState.isSignedIn ? const FeedScreen() : const LoginScreen();
  }
}
