import 'package:flutter/foundation.dart';

import 'calc.dart';
import 'food_db.dart';
import 'models.dart';
import 'storage.dart';

/// Single source of truth for saved data. Screens listen to it.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  bool loaded = false;
  Profile? profile;
  List<WalkRecord> walks = []; // newest first, summaries only
  List<FoodEntry> food = [];
  List<FoodItem> customFoods = [];
  List<WeightEntry> weights = []; // oldest first
  String geminiKey = '';
  String geminiModel = ''; // '' = choose automatically
  String mapKey = ''; // CARTO key entered in Settings (optional)

  Plan? get plan => profile == null ? null : computePlan(profile!);

  Future<void> load() async {
    final p = await Store.read('profile.json');
    if (p is Map<String, dynamic>) profile = Profile.fromJson(p);

    final w = await Store.read('walks.json');
    if (w is List) {
      walks = w
          .whereType<Map<String, dynamic>>()
          .map((e) => WalkRecord.fromJson(e))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));
    }
    final f = await Store.read('food.json');
    if (f is List) {
      food = f.whereType<Map<String, dynamic>>().map(FoodEntry.fromJson).toList();
    }
    final c = await Store.read('custom_foods.json');
    if (c is List) {
      customFoods =
          c.whereType<Map<String, dynamic>>().map(FoodItem.fromJson).toList();
    }
    final wt = await Store.read('weights.json');
    if (wt is List) {
      weights = wt
          .whereType<Map<String, dynamic>>()
          .map(WeightEntry.fromJson)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    final s = await Store.read('settings.json');
    if (s is Map<String, dynamic>) {
      geminiKey = (s['geminiKey'] ?? '') as String;
      geminiModel = (s['geminiModel'] ?? '') as String;
      mapKey = (s['mapKey'] ?? '') as String;
    }
    loaded = true;
    notifyListeners();
  }

  // ---------- profile ----------
  Future<void> saveProfile(Profile p, {bool logWeight = true}) async {
    profile = p;
    await Store.write('profile.json', p.toJson());
    if (logWeight) await _upsertWeight(dayKey(DateTime.now()), p.weightKg);
    notifyListeners();
  }

  Future<void> resetAll() async {
    for (final n in [
      'profile.json',
      'walks.json',
      'food.json',
      'custom_foods.json',
      'weights.json',
      'settings.json',
      'active_walk.json',
    ]) {
      await Store.delete(n);
    }
    for (final w in walks) {
      await Store.delete('routes/${w.id}.json');
    }
    profile = null;
    walks = [];
    food = [];
    customFoods = [];
    weights = [];
    geminiKey = '';
    geminiModel = '';
    mapKey = '';
    notifyListeners();
  }

  Future<void> setGeminiKey(String key) async {
    geminiKey = key.trim();
    await _saveSettings();
  }

  Future<void> setGeminiModel(String model) async {
    geminiModel = model;
    await _saveSettings();
  }

  Future<void> setMapKey(String key) async {
    mapKey = key.trim();
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    await Store.write('settings.json',
        {'geminiKey': geminiKey, 'geminiModel': geminiModel, 'mapKey': mapKey});
    notifyListeners();
  }

  // ---------- walks ----------
  Future<void> addWalk(WalkRecord r) async {
    await Store.write(
        'routes/${r.id}.json', r.points.map((p) => p.toJson()).toList());
    walks.insert(0, r);
    await Store.write('walks.json', walks.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteWalk(String id) async {
    walks.removeWhere((w) => w.id == id);
    await Store.write('walks.json', walks.map((e) => e.toJson()).toList());
    await Store.delete('routes/$id.json');
    notifyListeners();
  }

  Future<List<TrackPoint>> loadRoute(String id) async {
    final r = await Store.read('routes/$id.json');
    if (r is! List) return [];
    return r.whereType<List<dynamic>>().map(TrackPoint.fromJson).toList();
  }

  List<WalkRecord> walksOn(String day) =>
      walks.where((w) => dayKey(w.start) == day).toList();

  double walkKcalOn(String day) =>
      walksOn(day).fold(0.0, (s, w) => s + w.kcal);
  double walkMetersOn(String day) =>
      walksOn(day).fold(0.0, (s, w) => s + w.distanceM);
  int walkSecondsOn(String day) =>
      walksOn(day).fold(0, (s, w) => s + w.durationSec);

  // ---------- food ----------
  List<FoodEntry> foodOn(String day) =>
      food.where((f) => f.date == day).toList();
  double kcalEatenOn(String day) =>
      foodOn(day).fold(0.0, (s, f) => s + f.kcal);
  double proteinOn(String day) =>
      foodOn(day).fold(0.0, (s, f) => s + f.protein);

  Future<void> addFood(FoodEntry e) async {
    food.add(e);
    await _saveFood();
  }

  Future<void> updateFood(FoodEntry e) async {
    final i = food.indexWhere((f) => f.id == e.id);
    if (i >= 0) food[i] = e;
    await _saveFood();
  }

  Future<void> removeFood(String id) async {
    food.removeWhere((f) => f.id == id);
    await _saveFood();
  }

  Future<void> _saveFood() async {
    await Store.write('food.json', food.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  List<FoodItem> get allFoods => [...customFoods, ...foodDb];

  /// Foods logged most often recently, for quick re-adding.
  List<FoodItem> recentFoods([int n = 8]) {
    final counts = <String, int>{};
    for (final f in food.reversed.take(150)) {
      counts[f.foodId] = (counts[f.foodId] ?? 0) + 1;
    }
    final ids = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final all = allFoods;
    final out = <FoodItem>[];
    for (final id in ids) {
      final m = all.where((f) => f.id == id);
      if (m.isNotEmpty) out.add(m.first);
      if (out.length >= n) break;
    }
    return out;
  }

  Future<FoodItem> addCustomFood(
      String name, String serving, double kcal, double protein,
      {String category = 'My foods'}) async {
    final existing = customFoods.where(
        (f) => f.name.toLowerCase() == name.toLowerCase() && f.serving == serving);
    if (existing.isNotEmpty) return existing.first;
    final item = FoodItem('c_${DateTime.now().microsecondsSinceEpoch}', name,
        serving, kcal, protein, category,
        custom: true);
    customFoods.insert(0, item);
    await Store.write(
        'custom_foods.json', customFoods.map((e) => e.toJson()).toList());
    notifyListeners();
    return item;
  }

  Future<void> deleteCustomFood(String id) async {
    customFoods.removeWhere((f) => f.id == id);
    await Store.write(
        'custom_foods.json', customFoods.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  // ---------- weight ----------
  Future<void> logWeight(double kg, [DateTime? on]) async {
    final day = dayKey(on ?? DateTime.now());
    await _upsertWeight(day, kg);
    // The latest entry becomes the current weight and the plan follows it.
    final latest = weights.last;
    if (profile != null && latest.date == day) {
      profile!.weightKg = kg;
      await Store.write('profile.json', profile!.toJson());
    }
    notifyListeners();
  }

  Future<void> deleteWeight(String date) async {
    weights.removeWhere((w) => w.date == date);
    await Store.write('weights.json', weights.map((e) => e.toJson()).toList());
    if (profile != null && weights.isNotEmpty) {
      profile!.weightKg = weights.last.kg;
      await Store.write('profile.json', profile!.toJson());
    }
    notifyListeners();
  }

  Future<void> _upsertWeight(String day, double kg) async {
    weights.removeWhere((w) => w.date == day);
    weights.add(WeightEntry(day, kg));
    weights.sort((a, b) => a.date.compareTo(b.date));
    await Store.write('weights.json', weights.map((e) => e.toJson()).toList());
  }
}
