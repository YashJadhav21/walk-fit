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

class _Http {
  final int status;
  final String body;
  _Http(this.status, this.body);

  /// Google's own error text, e.g. "API key not valid".
  String get apiMessage {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      return (j['error']?['message'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }
}

/// Calls the Gemini REST API with the user's own key. Used only as a
/// fallback for foods that are not in the offline list.
///
/// Free-tier model availability changes often, so instead of hard-coding
/// one model the app asks Google which models this key can use
/// (models.list), prefers the newest stable Flash / Flash-Lite models, and
/// falls through to the next one on "not found" or "quota" errors.
class Gemini {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  /// Used if listing models fails for some reason.
  static const fallbackModels = [
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ];

  static List<String>? _cachedModels;
  static String? _cachedForKey;
  static String? lastWorkingModel;

  static Future<_Http> _send(String method, String url, String key,
      [Object? body]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = method == 'GET'
          ? await client.getUrl(Uri.parse(url))
          : await client.postUrl(Uri.parse(url));
      req.headers.set('x-goog-api-key', key.trim());
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 60));
      final text = await res.transform(utf8.decoder).join();
      return _Http(res.statusCode, text);
    } on SocketException {
      throw GeminiException('No internet connection.');
    } on HandshakeException {
      throw GeminiException('Secure connection failed. Check your internet.');
    } on TimeoutException {
      throw GeminiException('Gemini took too long. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  /// Text models this key can call, best first.
  static Future<List<String>> listModels(String key, {bool refresh = false}) async {
    if (!refresh && _cachedModels != null && _cachedForKey == key) {
      return _cachedModels!;
    }
    final r = await _send('GET', '$_base/models?pageSize=1000', key);
    if (r.status == 400 || r.status == 401 || r.status == 403) {
      final m = r.apiMessage;
      throw GeminiException(m.isNotEmpty
          ? 'Key rejected by Google: $m'
          : 'The Gemini API key is not valid.');
    }
    if (r.status != 200) return fallbackModels;

    final names = <String>[];
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      for (final m in (j['models'] as List? ?? const [])) {
        final mm = m as Map<String, dynamic>;
        final name = (mm['name'] ?? '').toString().replaceFirst('models/', '');
        final methods = (mm['supportedGenerationMethods'] as List? ?? const [])
            .map((e) => e.toString());
        if (!methods.contains('generateContent')) continue;
        if (!name.startsWith('gemini')) continue;
        if (!name.contains('flash')) continue; // Pro is paid-only now
        const skip = [
          'image', 'tts', 'live', 'audio', 'embedding', 'vision', 'transcribe',
          'computer', 'robotics', 'omni', 'translate', 'native', 'thinking',
        ];
        if (skip.any(name.contains)) continue;
        names.add(name);
      }
    } catch (_) {
      return fallbackModels;
    }
    if (names.isEmpty) return fallbackModels;
    names.sort((a, b) => _score(b).compareTo(_score(a)));
    _cachedModels = names;
    _cachedForKey = key;
    return names;
  }

  /// Higher is better: stable > preview > experimental, newer version,
  /// Flash before Flash-Lite, "-latest" aliases near the top.
  static double _score(String n) {
    var s = 0.0;
    final v = RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(n);
    if (v != null) s += double.parse(v.group(1)!) * 10;
    if (n.endsWith('-latest')) s += 45;
    if (n.contains('preview')) s -= 25;
    if (n.contains('exp')) s -= 40;
    if (n.contains('lite')) s -= 3;
    if (RegExp(r'-\d{3}$').hasMatch(n)) s -= 1; // pinned versions after alias
    return s;
  }

  static Future<List<AiFood>> estimate(String key, String query,
      {String preferredModel = ''}) async {
    var models = await listModels(key);
    final first = preferredModel.isNotEmpty ? preferredModel : lastWorkingModel;
    if (first != null && first.isNotEmpty) {
      models = [first, ...models.where((m) => m != first)];
    }
    String lastError = 'No Gemini model is available for this key.';
    var tried = 0;
    for (final model in models) {
      if (tried >= 6) break;
      tried++;
      final r = await _send('POST', '$_base/models/$model:generateContent', key,
          _requestBody(query));
      if (r.status == 200) {
        final foods = _parse(r.body, query);
        lastWorkingModel = model;
        return foods;
      }
      final msg = r.apiMessage;
      if (r.status == 400 && msg.toLowerCase().contains('api key')) {
        throw GeminiException('Key rejected by Google: $msg');
      }
      // Model missing, not on the free tier, over quota, or overloaded:
      // try the next model.
      if (r.status == 404 || r.status == 429 || r.status == 403 ||
          r.status == 500 || r.status == 503 || r.status == 400) {
        lastError = r.status == 429
            ? 'Free Gemini limit reached for now. Try again in a minute.'
            : (msg.isNotEmpty ? msg : 'Gemini error ${r.status}');
        continue;
      }
      lastError = msg.isNotEmpty ? msg : 'Gemini error ${r.status}';
    }
    throw GeminiException(lastError);
  }

  static Map<String, dynamic> _requestBody(String query) => {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': '''
You are a nutrition assistant for an Indian vegetarian user. Estimate calories and protein for what the user ate.
Rules:
- Split the input into separate foods if it lists several.
- Use typical Indian home-style recipes and portions unless a quantity is given.
- "serving" describes the exact amount you assumed (e.g. "2 medium rotis", "1 bowl (150 g)").
- kcal and protein_g are totals for that serving, as numbers.
- vegetarian is false if the food contains egg, meat, fish or gelatin.
Reply with JSON only, exactly in this shape:
{"foods":[{"name":"...","serving":"...","kcal":0,"protein_g":0,"vegetarian":true}]}
User input: "$query"'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      };

  static List<AiFood> _parse(String body, String query) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>? ?? const [];
      if (candidates.isEmpty) {
        throw GeminiException('Gemini returned no answer. Try rephrasing.');
      }
      final parts =
          (candidates.first['content']?['parts'] as List<dynamic>?) ?? const [];
      final text = parts
          .where((p) => p is Map && p['thought'] != true)
          .map((p) => (p as Map)['text']?.toString() ?? '')
          .join();
      final decoded = jsonDecode(_extractJson(text));
      final List<dynamic> list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['foods'] as List? ?? [decoded]) : const []);
      final foods = <AiFood>[];
      for (final e in list) {
        if (e is! Map) continue;
        final kcal = _num(e['kcal'] ?? e['calories']);
        if (kcal <= 0) continue;
        foods.add(AiFood(
          (e['name'] ?? query).toString(),
          (e['serving'] ?? '1 serving').toString(),
          kcal,
          _num(e['protein_g'] ?? e['protein']),
          e['vegetarian'] != false,
        ));
      }
      if (foods.isEmpty) {
        throw GeminiException('Could not estimate that. Try adding a quantity.');
      }
      return foods;
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw GeminiException('Unexpected reply from Gemini. Try again.');
    }
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0;
  }

  static String _extractJson(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '');
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
      t = t.trim();
    }
    final i = t.indexOf(RegExp(r'[\[{]'));
    final j = t.lastIndexOf(RegExp(r'[\]}]'));
    if (i >= 0 && j > i) t = t.substring(i, j + 1);
    return t;
  }
}
