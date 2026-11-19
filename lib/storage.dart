import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tiny JSON file store in the app's private documents folder.
class Store {
  static Directory? _dir;

  static Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/walkfit');
    if (!await d.exists()) await d.create(recursive: true);
    final routes = Directory('${d.path}/routes');
    if (!await routes.exists()) await routes.create(recursive: true);
    _dir = d;
    return d;
  }

  static Future<File> _file(String name) async =>
      File('${(await dir()).path}/$name');

  static Future<dynamic> read(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      if (text.trim().isEmpty) return null;
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  /// Writes atomically (temp file + rename) so a crash never leaves a
  /// half-written file behind.
  static Future<void> write(String name, Object? data) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  static Future<void> delete(String name) async {
    try {
      final f = await _file(name);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
