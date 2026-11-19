// Renders every main screen with sample data. Fails on layout errors
// (overflows etc.) and saves screenshots to test/goldens/ when run with
// `flutter test --update-goldens test/screens_test.dart`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkfit/app_state.dart';
import 'package:walkfit/main.dart';
import 'package:walkfit/models.dart';
import 'package:walkfit/ui/add_food_page.dart';
import 'package:walkfit/ui/food_page.dart';
import 'package:walkfit/ui/meal_plan_page.dart';
import 'package:walkfit/ui/profile_form.dart';
import 'package:walkfit/ui/progress_page.dart';
import 'package:walkfit/ui/settings_page.dart';
import 'package:walkfit/ui/today_page.dart';
import 'package:walkfit/ui/walk_detail_page.dart';
import 'package:walkfit/ui/walk_page.dart';
import 'package:walkfit/tracker.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, Iterable<File> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await l.load();
  }

  final assets = Directory('assets/fonts').listSync().whereType<File>().toList();
  await load('Inter', assets.where((f) => f.path.contains('/Inter-')));
  await load('InterDisplay', assets.where((f) => f.path.contains('/InterDisplay-')));
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await load('MaterialIcons', [icons]);
}

void _seed() {
  final s = AppState.instance;
  s.profile = Profile(
    name: 'Yash Jadhav',
    sex: 'male',
    age: 24,
    heightCm: 172,
    weightKg: 78.6,
    goalKg: 70,
    activity: 0,
    paceKgPerWeek: 0.5,
    walkGoalKcal: 190,
  );
  final now = DateTime.now();
  final today = dayKey(now);
  final pts = <TrackPoint>[];
  for (var i = 0; i < 60; i++) {
    pts.add(TrackPoint(18.5204 + i * 0.00025, 73.8567 + (i % 20) * 0.0002,
        now.millisecondsSinceEpoch + i * 10000, 0));
  }
  s.walks = [
    WalkRecord(
        id: 'w1',
        start: now.subtract(const Duration(hours: 2)),
        end: now.subtract(const Duration(hours: 1, minutes: 20)),
        durationSec: 2400,
        distanceM: 3420,
        kcal: 142,
        points: pts),
  ];
  FoodEntry e(String meal, String name, String serving, double q, double k, double p) =>
      FoodEntry(
          id: name,
          date: today,
          meal: meal,
          foodId: name,
          name: name,
          serving: serving,
          qty: q,
          kcalPerServing: k,
          proteinPerServing: p);
  s.food = [
    e('Breakfast', 'Poha', '1 plate (150 g)', 1, 250, 5),
    e('Breakfast', 'Tea with milk, no sugar', '1 cup', 1, 35, 1.5),
    e('Lunch', 'Roti / chapati (no ghee)', '1 medium', 2, 85, 3),
    e('Lunch', 'Toor dal / varan', '1 bowl (150 ml)', 1, 150, 7),
    e('Lunch', 'Mixed veg sabzi', '1 bowl (150 g)', 1, 120, 3),
  ];
  s.weights = [
    WeightEntry(dayKey(now.subtract(const Duration(days: 21))), 80),
    WeightEntry(dayKey(now.subtract(const Duration(days: 14))), 79.6),
    WeightEntry(dayKey(now.subtract(const Duration(days: 7))), 79.1),
    WeightEntry(today, 78.6),
  ];
  s.loaded = true;
}

Widget _wrap(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(b),
      home: child,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    final tmp = Directory.systemTemp.createTempSync('walkfit');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    _seed();
  });

  final screens = <String, Widget Function()>{
    '01_setup': () => const ProfileFormPage(firstRun: true),
    '02_plan': () => PlanReviewPage(profile: AppState.instance.profile!, firstRun: true),
    '03_today': () => const Scaffold(body: TodayPage()),
    '04_food': () => const FoodPage(),
    '05_add_food': () => const AddFoodPage(meal: 'Dinner', date: '2026-01-01'),
    '06_meal_ideas': () => const MealPlanPage(),
    '07_walk_detail': () => WalkDetailPage(walk: AppState.instance.walks.first),
    '08_progress': () => const ProgressPage(),
    '09_settings': () => const SettingsPage(),
    '10_walk_idle': () => const Scaffold(body: WalkPage()),
    '11_walk_active': () {
      final tr = WalkTracker.instance;
      tr.points
        ..clear()
        ..addAll(AppState.instance.walks.first.points.take(40));
      tr.distanceM = 2350;
      tr.kcal = 98;
      tr.startedAt = DateTime.now();
      tr.status = WalkStatus.paused;
      return const Scaffold(body: WalkPage());
    },
  };

  for (final entry in screens.entries) {
    for (final b in [Brightness.light, Brightness.dark]) {
      if (b == Brightness.dark && !(entry.key.startsWith('03') || entry.key.startsWith('11') || entry.key.startsWith('04'))) continue;
      testWidgets('${entry.key} ${b.name}', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(entry.value(), b: b));
        await tester.pump(const Duration(milliseconds: 500));
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('goldens/${entry.key}_${b.name}.png'));
      });
    }
  }
}
