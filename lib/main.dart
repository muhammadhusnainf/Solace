import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

ThemeData _buildTheme(Color seed, Brightness brightness, DarkShade shade) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final neutral = dark && shade.surface != null;
  final scheme = neutral
      ? base.copyWith(
          surface: shade.surface,
          surfaceBright: shade.layers[4],
          surfaceDim: shade.layers[0],
          surfaceContainerLowest: shade.layers[0],
          surfaceContainerLow: shade.layers[1],
          surfaceContainer: shade.layers[2],
          surfaceContainerHigh: shade.layers[3],
          surfaceContainerHighest: shade.layers[4],
        )
      : dark
      ? base.copyWith(
          surface: _tint(seed, 0.09, 0.32),
          surfaceBright: _tint(seed, 0.20, 0.30),
          surfaceDim: _tint(seed, 0.06, 0.30),
          surfaceContainerLowest: _tint(seed, 0.07, 0.30),
          surfaceContainerLow: _tint(seed, 0.11, 0.32),
          surfaceContainer: _tint(seed, 0.14, 0.34),
          surfaceContainerHigh: _tint(seed, 0.17, 0.34),
          surfaceContainerHighest: _tint(seed, 0.20, 0.34),
        )
      : base.copyWith(
          surface: _tint(seed, 0.93, 0.50),
          surfaceBright: _tint(seed, 0.96, 0.46),
          surfaceDim: _tint(seed, 0.88, 0.46),
          surfaceContainerLowest: _tint(seed, 0.97, 0.40),
          surfaceContainerLow: _tint(seed, 0.94, 0.46),
          surfaceContainer: _tint(seed, 0.91, 0.48),
          surfaceContainerHigh: _tint(seed, 0.88, 0.50),
          surfaceContainerHighest: _tint(seed, 0.85, 0.52),
        );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: neutral
          ? shade.layers[2]
          : dark
              ? _tint(seed, 0.30, 0.55)
              : scheme.primary,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      scrolledUnderElevation: 3,
      shadowColor: Colors.black,
      shape: Border(
        bottom: BorderSide(color: Colors.black.withValues(alpha: 0.18)),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primary,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final on = states.contains(WidgetState.selected);
        return IconThemeData(
          color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final on = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          color: on ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mode = await ThemeNotifier.loadSaved();
  final accent = await AccentNotifier.loadSaved();
  final shade = await DarkShadeNotifier.loadSaved();
  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(() => ThemeNotifier(mode)),
        accentProvider.overrideWith(() => AccentNotifier(accent)),
        darkShadeProvider.overrideWith(() => DarkShadeNotifier(shade)),
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
    final shade = ref.watch(darkShadeProvider);

    return MaterialApp(
      title: 'Solace',
      theme: _buildTheme(accent.seed, Brightness.light, shade),
      darkTheme: _buildTheme(accent.seed, Brightness.dark, shade),
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
