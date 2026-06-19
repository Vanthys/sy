import 'dart:ui';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/tracker_list_screen.dart';
import 'logic/theme_provider.dart';
import 'logic/vault_provider.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWith((ref) => prefs)],
      child: const RestartWidget(
        child: SyApp(),
      ),
    ),
  );
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class SyApp extends ConsumerStatefulWidget {
  const SyApp({super.key});

  @override
  ConsumerState<SyApp> createState() => _SyAppState();
}

class _SyAppState extends ConsumerState<SyApp> {
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: _lockVault,
      onHide: _lockVault,
      onDetach: _lockVault,
    );
  }

  void _lockVault() {
    ref.read(vaultProvider.notifier).lockVault();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final customSeed = ref.watch(seedColorProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme;
        final ColorScheme darkScheme;

        final ColorScheme baseLight;
        final ColorScheme baseDark;

        if (customSeed != null) {
          baseLight = ColorScheme.fromSeed(
            seedColor: customSeed,
            brightness: Brightness.light,
          );
          baseDark = ColorScheme.fromSeed(
            seedColor: customSeed,
            brightness: Brightness.dark,
          );
        } else if (lightDynamic != null && darkDynamic != null) {
          baseLight = lightDynamic.harmonized();
          baseDark = darkDynamic.harmonized();
        } else {
          baseLight = ColorScheme.fromSeed(
            seedColor: kFallbackSeed,
            brightness: Brightness.light,
          );
          baseDark = ColorScheme.fromSeed(
            seedColor: kFallbackSeed,
            brightness: Brightness.dark,
          );
        }

        lightScheme = withStableSurfaces(baseLight, Brightness.light);
        darkScheme = withStableSurfaces(baseDark, Brightness.dark);

        final lightTheme = buildTheme(lightScheme);
        final darkTheme = buildTheme(darkScheme);
        final amoledTheme = buildAmoledTheme(darkTheme);

        final activeDarkTheme = themeMode == AppThemeMode.amoled
            ? amoledTheme
            : darkTheme;

        final activeThemeMode = switch (themeMode) {
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark || AppThemeMode.amoled => ThemeMode.dark,
          AppThemeMode.system => ThemeMode.system,
        };

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: AppScrollBehavior(),
          title: 'SY',
          theme: lightTheme,
          darkTheme: activeDarkTheme,
          themeMode: activeThemeMode,
          home: const TrackerListScreen(),
        );
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
