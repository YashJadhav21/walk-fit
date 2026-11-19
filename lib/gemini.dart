import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One food estimated by Gemini.
class AiFood {
  final String name;
  final String serving;
  final double kcal;
  final double protein;
  final bool vegetarian;
  const AiFood(this.name, this.serving, this.kcal, this.protein, this.vegetarian);
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

/// Calls the Gemini REST API directly. Used only as a fallback when a food
/// is not in the offline list. The key is the user's own, stored on device.
class Gemini {
  // Tried in order; the first that exists for the key is remembered.
  static const _models = [
    'gemini-flash-latest',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ];
  static String? _workingModel;

  static Future<List<AiFood>> estimate(String apiKey, String query) async {
    final models = _workingModel != null
        ? [_workingModel!, ..._models.where((m) => m != _workingModel)]
        : _models;
    GeminiException? last;
    for (final model in models) {
      try {
        final r = await _call(apiKey, model, query);
        _workingModel = model;
        return r;
      } on _ModelMissing {
        continue;
      } on GeminiException catch (e) {
        last = e;
        break;
      }
    }
    throw last ?? GeminiException('No Gemini model is available for this key.');
  }

  static Future<List<AiFood>> _call(
      String apiKey, String model, String query) async {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final prompt = '''
You are a nutrition assistant for an Indian user. Estimate calories and protein for the food the user ate.
Rules:
- Split the input into separate foods if it lists several.
- Use typical Indian home-style recipes and portions unless the user gives a quantity.
- "serving" must describe the exact amount you assumed (e.g. "2 medium rotis", "1 bowl (150 g)").
- kcal and protein_g are totals for that serving.
- vegetarian is false if the food contains egg, meat, fish or gelatin.
User input: "$query"''';

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'name': {'type': 'STRING'},
              'serving': {'type': 'STRING'},
              'kcal': {'type': 'NUMBER'},
              'protein_g': {'type': 'NUMBER'},
              'vegetarian': {'type': 'BOOLEAN'},
            },
            'required': ['name', 'serving', 'kcal', 'protein_g', 'vegetarian'],
          },
        },
      },
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set('x-goog-api-key', apiKey.trim());
      req.add(utf8.encode(body));
      final res = await req.close().timeout(const Duration(seconds: 40));
      final text = await res.transform(utf8.decoder).join();

      if (res.statusCode == 404) throw _ModelMissing();
      if (res.statusCode == 400 && text.contains('API key')) {
        throw GeminiException('The Gemini API key is not valid. Check it in Settings.');
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw GeminiException('The Gemini API key was rejected. Check it in Settings.');
      }
      if (res.statusCode == 429) {
        throw GeminiException('Gemini limit reached. Try again in a minute.');
      }
      if (res.statusCode != 200) {
        throw GeminiException('Gemini error (${res.statusCode}). Try again.');
      }

      final data = jsonDecode(text) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiException('Gemini returned no answer. Try rephrasing.');
      }
      final parts = (candidates.first['content']?['parts'] as List<dynamic>?) ?? [];
      final out = parts
          .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
          .join();
      final list = jsonDecode(_stripFences(out)) as List<dynamic>;
      final foods = <AiFood>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final kcal = (m['kcal'] as num?)?.toDouble() ?? 0;
        if (kcal <= 0) continue;
        foods.add(AiFood(
          (m['name'] ?? query).toString(),
          (m['serving'] ?? '1 serving').toString(),
          kcal,
          (m['protein_g'] as num?)?.toDouble() ?? 0,
          m['vegetarian'] != false,
        ));
      }
      if (foods.isEmpty) {
        throw GeminiException('Could not estimate that food. Try adding a quantity.');
      }
      return foods;
    } on SocketException {
      throw GeminiException('No internet connection.');
    } on TimeoutException {
      throw GeminiException('Gemini took too long. Try again.');
    } on FormatException {
      throw GeminiException('Unexpected reply from Gemini. Try again.');
    } finally {
      client.close();
    }
  }

  static String _stripFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }
}

class _ModelMissing implements Exception {}
