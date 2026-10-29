import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppAccent {
  const AppAccent(this.seed, [this.gradient]);

  final Color seed;
  final List<Color>? gradient;

  String get id => gradient == null
      ? 'c${seed.toARGB32()}'
      : 'g${gradient!.first.toARGB32()}';
}

const AppAccent defaultAccent = AppAccent(Colors.deepPurple);

const List<AppAccent> accentChoices = [
  AppAccent(Colors.deepPurple),
  AppAccent(Colors.indigo),
  AppAccent(Colors.blue),
  AppAccent(Colors.teal),
  AppAccent(Colors.green),
  AppAccent(Colors.orange),
  AppAccent(Colors.pink),
  AppAccent(Colors.red),
];

const List<AppAccent> gradientChoices = [
  AppAccent(Color(0xFF2193B0), [Color(0xFF2193B0), Color(0xFF6DD5ED)]),
  AppAccent(Color(0xFFFF7E5F), [Color(0xFFFF7E5F), Color(0xFFFEB47B)]),
  AppAccent(Color(0xFF43CEA2), [Color(0xFF43CEA2), Color(0xFF185A9D)]),
  AppAccent(Color(0xFF8E2DE2), [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
  AppAccent(Color(0xFFFF758C), [Color(0xFFFF758C), Color(0xFFFF7EB3)]),
];

LinearGradient? softGradient(AppAccent accent, Brightness brightness) {
  final colors = accent.gradient;
  if (colors == null || brightness == Brightness.dark) return null;
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [for (final c in colors) Color.lerp(c, Colors.white, 0.72)!],
  );
}

class ThemeNotifier extends Notifier<ThemeMode> {
  ThemeNotifier([this._initial = ThemeMode.system]);

  static const _key = 'theme_mode';

  final ThemeMode _initial;

  static Future<ThemeMode> loadSaved() async {
    try {
      final saved = await const FlutterSecureStorage().read(key: _key);
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'light') return ThemeMode.light;
    } catch (_) {}
    return ThemeMode.system;
  }

  @override
  ThemeMode build() => _initial;

  Future<void> setDark(bool dark) async {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    try {
      await const FlutterSecureStorage()
          .write(key: _key, value: dark ? 'dark' : 'light');
    } catch (_) {}
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class AccentNotifier extends Notifier<AppAccent> {
  AccentNotifier([this._initial = defaultAccent]);

  static const _key = 'accent_color';

  final AppAccent _initial;

  static Future<AppAccent> loadSaved() async {
    try {
      final saved = await const FlutterSecureStorage().read(key: _key);
      if (saved != null) {
        for (final a in [...accentChoices, ...gradientChoices]) {
          if (a.id == saved) return a;
        }
        final legacy = int.tryParse(saved);
        if (legacy != null) return AppAccent(Color(legacy));
      }
    } catch (_) {}
    return defaultAccent;
  }

  @override
  AppAccent build() => _initial;

  Future<void> set(AppAccent accent) async {
    state = accent;
    try {
      await const FlutterSecureStorage().write(key: _key, value: accent.id);
    } catch (_) {}
  }
}

final accentProvider =
    NotifierProvider<AccentNotifier, AppAccent>(AccentNotifier.new);
