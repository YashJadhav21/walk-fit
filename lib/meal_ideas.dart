import 'food_db.dart';
import 'models.dart';

/// Share of the daily calorie budget per meal.
const mealSplit = {
  'Breakfast': 0.25,
  'Lunch': 0.35,
  'Snacks': 0.10,
  'Dinner': 0.30,
};

class MealIdea {
  final String meal;
  final List<(String, double)> parts; // (foodId, servings)
  const MealIdea(this.meal, this.parts);

  List<(FoodItem, double)> get items => [
        for (final p in parts)
          (foodDb.firstWhere((f) => f.id == p.$1), p.$2),
      ];
  double get kcal => items.fold(0.0, (s, e) => s + e.$1.kcal * e.$2);
  double get protein => items.fold(0.0, (s, e) => s + e.$1.protein * e.$2);
}

/// Vegetarian (dairy, no egg) combos that are filling and protein-forward.
const mealIdeas = <MealIdea>[
  // Breakfast
  MealIdea('Breakfast', [('moong_chilla', 2.0), ('curd', 1.0)]),
  MealIdea('Breakfast', [('besan_chilla', 2.0), ('chutney_green', 1.0), ('tea_nosugar', 1.0)]),
  MealIdea('Breakfast', [('poha', 1.0), ('chaas', 1.0)]),
  MealIdea('Breakfast', [('idli', 3.0), ('sambar', 1.0)]),
  MealIdea('Breakfast', [('oats_milk', 1.0), ('almonds', 1.0)]),
  MealIdea('Breakfast', [('paneer_sandwich', 1.0)]),
  MealIdea('Breakfast', [('upma', 1.0), ('tea_nosugar', 1.0)]),
  MealIdea('Breakfast', [('daliya', 1.0), ('milk_toned', 1.0)]),
  MealIdea('Breakfast', [('greek_yogurt', 1.5), ('banana', 1.0), ('almonds', 1.0)]),
  MealIdea('Breakfast', [('dhokla', 2.0), ('tea_nosugar', 1.0)]),
  MealIdea('Breakfast', [('thalipeeth', 1.0), ('curd', 1.0)]),

  // Lunch
  MealIdea('Lunch', [('roti', 2.0), ('toor_dal', 1.0), ('mix_veg', 1.0), ('green_salad', 1.0)]),
  MealIdea('Lunch', [('jowar_bhakri', 2.0), ('pithla', 1.0), ('koshimbir', 1.0)]),
  MealIdea('Lunch', [('roti', 2.0), ('rajma', 1.0), ('raita', 1.0)]),
  MealIdea('Lunch', [('rice', 1.0), ('dal_tadka', 1.0), ('bhindi', 1.0), ('green_salad', 1.0)]),
  MealIdea('Lunch', [('roti', 2.0), ('palak_paneer', 1.0), ('green_salad', 1.0)]),
  MealIdea('Lunch', [('roti', 2.0), ('soya_curry', 1.0), ('curd', 1.0)]),
  MealIdea('Lunch', [('brown_rice', 1.0), ('chole', 1.0), ('green_salad', 1.0)]),
  MealIdea('Lunch', [('roti', 3.0), ('usal', 1.0), ('chaas', 1.0)]),
  MealIdea('Lunch', [('khichdi', 1.5), ('curd', 1.0), ('papad', 1.0)]),

  // Snacks
  MealIdea('Snacks', [('chana_roasted', 1.0), ('tea_nosugar', 1.0)]),
  MealIdea('Snacks', [('makhana', 1.0), ('chaas', 1.0)]),
  MealIdea('Snacks', [('apple', 1.0), ('almonds', 1.0)]),
  MealIdea('Snacks', [('sprouts', 1.0)]),
  MealIdea('Snacks', [('guava', 1.0), ('chaas', 1.0)]),
  MealIdea('Snacks', [('boiled_chana', 1.0)]),
  MealIdea('Snacks', [('whey', 1.0)]),
  MealIdea('Snacks', [('papaya', 1.0), ('greek_yogurt', 1.0)]),

  // Dinner
  MealIdea('Dinner', [('roti', 2.0), ('paneer_bhurji', 0.75), ('green_salad', 1.0)]),
  MealIdea('Dinner', [('moong_dal', 1.0), ('roti', 2.0), ('lauki', 1.0)]),
  MealIdea('Dinner', [('dal_soup', 1.0), ('tofu_bhurji', 1.0), ('green_salad', 1.0)]),
  MealIdea('Dinner', [('khichdi', 1.0), ('kadhi', 1.0)]),
  MealIdea('Dinner', [('bajra_bhakri', 1.0), ('methi', 1.0), ('moong_dal', 1.0)]),
  MealIdea('Dinner', [('paneer_tikka', 1.0), ('clear_soup', 1.0), ('green_salad', 1.0)]),
  MealIdea('Dinner', [('roti', 2.0), ('matar', 1.0), ('curd', 1.0)]),
  MealIdea('Dinner', [('quinoa', 1.0), ('masoor_dal', 1.0), ('cabbage', 1.0)]),
];

/// Ideas for a meal that fit within [budgetKcal], most protein first.
List<MealIdea> ideasFor(String meal, double budgetKcal) {
  final all = mealIdeas.where((m) => m.meal == meal).toList();
  final fit = all.where((m) => m.kcal <= budgetKcal * 1.1).toList();
  final list = fit.isEmpty ? all : fit;
  list.sort((a, b) => (b.protein / b.kcal).compareTo(a.protein / a.kcal));
  return list;
}

const vegTips = [
  'Get protein at every meal: dal, paneer, curd, soya, sprouts, tofu or chana.',
  'Fill half the plate with sabzi or salad; it adds volume for few calories.',
  'Measure oil and ghee. 1 tsp is 45 kcal and it adds up fast in tadka.',
  'Swap sweet tea and soft drinks for chaas, lemon water or unsweetened tea.',
  'Prefer roti or bhakri over extra rice at night; keep dinner lighter.',
  'Fried snacks (vada pav, samosa, pakora) are 200–300 kcal each; keep them occasional.',
  'Drink water through the day. Thirst is often mistaken for hunger.',
];
