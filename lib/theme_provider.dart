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
  AppAccent(Colors.lightBlue),
  AppAccent(Colors.cyan),
  AppAccent(Colors.teal),
  AppAccent(Colors.green),
  AppAccent(Colors.lightGreen),
  AppAccent(Colors.amber),
  AppAccent(Colors.orange),
  AppAccent(Colors.deepOrange),
  AppAccent(Colors.red),
  AppAccent(Colors.pink),
  AppAccent(Colors.purple),
  AppAccent(Colors.brown),
  AppAccent(Colors.blueGrey),
];

const List<AppAccent> gradientChoices = [
  AppAccent(Color(0xFF2193B0), [Color(0xFF2193B0), Color(0xFF6DD5ED)]),
  AppAccent(Color(0xFFFF7E5F), [Color(0xFFFF7E5F), Color(0xFFFEB47B)]),
  AppAccent(Color(0xFF43CEA2), [Color(0xFF43CEA2), Color(0xFF185A9D)]),
  AppAccent(Color(0xFF8E2DE2), [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
  AppAccent(Color(0xFFFF758C), [Color(0xFFFF758C), Color(0xFFFF7EB3)]),
  AppAccent(Color(0xFFFF512F), [Color(0xFFFF512F), Color(0xFFDD2476)]),
  AppAccent(Color(0xFF1A2980), [Color(0xFF1A2980), Color(0xFF26D0CE)]),
  AppAccent(Color(0xFFDA22FF), [Color(0xFFDA22FF), Color(0xFF9733EE)]),
  AppAccent(Color(0xFF11998E), [Color(0xFF11998E), Color(0xFF2DBE6C)]),
  AppAccent(Color(0xFFFF416C), [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
  AppAccent(Color(0xFF141E30), [Color(0xFF141E30), Color(0xFF243B55)]),
  AppAccent(Color(0xFF134E5E), [Color(0xFF134E5E), Color(0xFF71B280)]),
  AppAccent(Color(0xFF2C3E50), [Color(0xFF2C3E50), Color(0xFF4CA1AF)]),
];

class DarkShade {
  const DarkShade(this.id, this.name, this.surface, this.layers);

  final String id;
  final String name;
  final Color? surface;
  final List<Color> layers;
}

const DarkShade defaultShade = DarkShade(
  'charcoal',
  'Charcoal',
  Color(0xFF121212),
  [
    Color(0xFF0E0E0E),
    Color(0xFF181818),
    Color(0xFF1E1E1E),
    Color(0xFF252525),
    Color(0xFF2C2C2C),
  ],
);

const List<DarkShade> darkShades = [
  DarkShade('accent', 'Accent', null, []),
  DarkShade(
    'black',
    'Pure black',
    Color(0xFF000000),
    [
      Color(0xFF000000),
      Color(0xFF0B0B0B),
      Color(0xFF121212),
      Color(0xFF191919),
      Color(0xFF212121),
    ],
  ),
  defaultShade,
  DarkShade(
    'graphite',
    'Graphite',
    Color(0xFF1C1C1E),
    [
      Color(0xFF161618),
      Color(0xFF232325),
      Color(0xFF2A2A2D),
      Color(0xFF323235),
      Color(0xFF3A3A3E),
    ],
  ),
  DarkShade(
    'slate',
    'Slate',
    Color(0xFF0F172A),
    [
      Color(0xFF0B1222),
      Color(0xFF151F35),
      Color(0xFF1A263F),
      Color(0xFF212F4B),
      Color(0xFF293A59),
    ],
  ),
  DarkShade(
    'midnight',
    'Midnight',
    Color(0xFF0A0F24),
    [
      Color(0xFF070B1C),
      Color(0xFF101733),
      Color(0xFF151D3F),
      Color(0xFF1B254C),
      Color(0xFF222E5A),
    ],
  ),
  DarkShade(
    'forest',
    'Forest',
    Color(0xFF0B1410),
    [
      Color(0xFF08100C),
      Color(0xFF111C16),
      Color(0xFF16241D),
      Color(0xFF1C2D24),
      Color(0xFF23362B),
    ],
  ),
  DarkShade(
    'espresso',
    'Espresso',
    Color(0xFF14100D),
    [
      Color(0xFF0F0B09),
      Color(0xFF1C1612),
      Color(0xFF231C17),
      Color(0xFF2B231D),
      Color(0xFF342A23),
    ],
  ),
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

Color _vivid(Color c, {required bool first, required bool dark}) {
  final hsl = HSLColor.fromColor(c);
  final sat = (hsl.saturation * 1.2).clamp(0.72, 1.0).toDouble();
  final light = (first
          ? hsl.lightness.clamp(0.22, 0.42)
          : hsl.lightness.clamp(0.38, 0.58))
      .toDouble();
  return hsl
      .withSaturation(sat)
      .withLightness(dark ? light * 0.7 : light)
      .toColor();
}

LinearGradient? boldGradient(
  AppAccent accent,
  Brightness brightness,
  DarkShade shade,
) {
  final colors = accent.gradient;
  if (colors == null) return null;
  final dark = brightness == Brightness.dark;
  if (dark && shade.surface != null) return null;
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      for (var i = 0; i < colors.length; i++)
        _vivid(colors[i], first: i == 0, dark: dark),
    ],
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

class DarkShadeNotifier extends Notifier<DarkShade> {
  DarkShadeNotifier([this._initial = defaultShade]);

  static const _key = 'dark_shade';

  final DarkShade _initial;

  static Future<DarkShade> loadSaved() async {
    try {
      final saved = await const FlutterSecureStorage().read(key: _key);
      for (final s in darkShades) {
        if (s.id == saved) return s;
      }
    } catch (_) {}
    return defaultShade;
  }

  @override
  DarkShade build() => _initial;

  Future<void> set(DarkShade shade) async {
    state = shade;
    try {
      await const FlutterSecureStorage().write(key: _key, value: shade.id);
    } catch (_) {}
  }
}

final darkShadeProvider =
    NotifierProvider<DarkShadeNotifier, DarkShade>(DarkShadeNotifier.new);
