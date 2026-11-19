# WalkFit

A simple Android app for walking and weight loss, built for vegetarians (dairy, no egg).

- **Walk tracking:** GPS runs only between **Start** and **Stop**, with Pause/Resume. You get live distance, time, pace and active calories, and your route is drawn on a free greyscale map (OpenStreetMap data, CARTO tiles, no API key).
- **Personal plan:** from your age, height, weight, goal and pace it works out a daily food budget, a walking goal and a protein target (Mifflin-St Jeor equation, 7700 kcal per kg).
- **Food log:** an offline list of 150+ Indian vegetarian foods with portions. Optional Gemini fallback (your own key, set in Settings) estimates any other food.
- **Meal ideas:** vegetarian combos sized to your budget.
- **Progress:** weight log and trend chart, plus a 7-day summary.

## Install

Open the [latest release](../../releases/latest) on your phone, download `WalkFit.apk`, and install it.

## Build

GitHub Actions builds the APK on every push to `main` (see `.github/workflows/build-apk.yml`).
The Android folder is generated in CI by `flutter create` and patched by `tool/patch_android.py`.

Local build: `flutter create --platforms=android --org com.yash --project-name walkfit . && python3 tool/patch_android.py && flutter build apk`
