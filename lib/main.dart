import 'package:flutter/material.dart';

import 'app_state.dart';
import 'tracker.dart';
import 'ui/home_shell.dart';
import 'ui/profile_form.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  final p = AppState.instance.profile;
  if (p != null) WalkTracker.instance.weightKg = p.weightKg;
  await WalkTracker.instance.restore();
  runApp(const WalkFitApp());
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E7A5A),
    brightness: b,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    visualDensity: VisualDensity.standard,
  );
}

class WalkFitApp extends StatelessWidget {
  const WalkFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkFit',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => AppState.instance.profile == null
            ? const ProfileFormPage(firstRun: true)
            : const HomeShell(),
      ),
    );
  }
}
