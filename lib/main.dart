import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Monochrome palette: black & white with greys. Red only for warnings.
class Mono {
  final Color bg, card, cardHigh, line, text, muted, faint;
  const Mono(this.bg, this.card, this.cardHigh, this.line, this.text,
      this.muted, this.faint);

  static const light = Mono(
    Color(0xFFFFFFFF),
    Color(0xFFF4F4F5),
    Color(0xFFE7E7E9),
    Color(0xFFE4E4E7),
    Color(0xFF0A0A0A),
    Color(0xFF71717A),
    Color(0xFFA1A1AA),
  );
  static const dark = Mono(
    Color(0xFF000000),
    Color(0xFF141414),
    Color(0xFF232323),
    Color(0xFF262626),
    Color(0xFFFAFAFA),
    Color(0xFF9F9FA7),
    Color(0xFF5F5F66),
  );
}

ThemeData appTheme(Brightness b) {
  final m = b == Brightness.dark ? Mono.dark : Mono.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: m.text,
    onPrimary: m.bg,
    primaryContainer: m.text,
    onPrimaryContainer: m.bg,
    secondary: m.muted,
    onSecondary: m.bg,
    secondaryContainer: m.text,
    onSecondaryContainer: m.bg,
    tertiary: m.muted,
    onTertiary: m.bg,
    error: const Color(0xFFE5484D),
    onError: Colors.white,
    errorContainer: const Color(0xFFE5484D),
    onErrorContainer: Colors.white,
    surface: m.bg,
    onSurface: m.text,
    onSurfaceVariant: m.muted,
    surfaceContainerLowest: m.bg,
    surfaceContainerLow: m.card,
    surfaceContainer: m.card,
    surfaceContainerHigh: m.cardHigh,
    surfaceContainerHighest: m.cardHigh,
    outline: m.faint,
    outlineVariant: m.line,
    inverseSurface: m.text,
    onInverseSurface: m.bg,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: 'Inter',
  );
  final tt = base.textTheme;
  TextStyle? display(TextStyle? s, double size, {FontWeight w = FontWeight.w700}) =>
      s?.copyWith(
          fontFamily: 'InterDisplay',
          fontSize: size,
          fontWeight: w,
          letterSpacing: -size * 0.03,
          height: 1.05);

  return base.copyWith(
    scaffoldBackgroundColor: m.bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: tt.copyWith(
      displayLarge: display(tt.displayLarge, 64, w: FontWeight.w800),
      displayMedium: display(tt.displayMedium, 52, w: FontWeight.w800),
      displaySmall: display(tt.displaySmall, 40, w: FontWeight.w800),
      headlineLarge: display(tt.headlineLarge, 34),
      headlineMedium: display(tt.headlineMedium, 30),
      headlineSmall: display(tt.headlineSmall, 26),
      titleLarge: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleSmall: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: tt.bodyLarge?.copyWith(letterSpacing: -0.1),
      labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: m.bg,
      foregroundColor: m.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: 'InterDisplay',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: m.text),
      systemOverlayStyle: b == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: m.text,
        foregroundColor: m.bg,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: m.text,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        side: BorderSide(color: m.line, width: 1.5),
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: m.text,
        textStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: m.text,
      foregroundColor: m.bg,
      elevation: 2,
      highlightElevation: 2,
      shape: const StadiumBorder(),
      extendedTextStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: m.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: m.card,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? m.text : m.faint, size: 24)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? m.text : m.faint)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: m.text,
      inactiveTrackColor: m.cardHigh,
      thumbColor: m.text,
      overlayColor: m.text.withValues(alpha: 0.08),
      trackHeight: 4,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: m.text,
      linearTrackColor: m.cardHigh,
      circularTrackColor: m.cardHigh,
    ),
    dividerTheme: DividerThemeData(color: m.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: m.text,
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: m.bg, fontSize: 14),
      actionTextColor: m.bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: m.bg,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: m.faint,
      showDragHandle: true,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: m.text,
      titleTextStyle: TextStyle(
          fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500, color: m.text),
      subtitleTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: m.muted),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? m.text : Colors.transparent),
      checkColor: WidgetStatePropertyAll(m.bg),
    ),
  );
}

class WalkFitApp extends StatelessWidget {
  const WalkFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WalkFit',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
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
