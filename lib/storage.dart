import 'dart:convert';
import 'dart:io';

/// Tiny JSON file store in the app's private documents folder.
class Store {
  static Directory? _dir;

  static Future<Directory> dir() async {
    if (_dir != null) return _dir!;
    final d = Directory('${_appDataDir()}/walkfit');
    if (!await d.exists()) await d.create(recursive: true);
    final routes = Directory('${d.path}/routes');
    if (!await routes.exists()) await routes.create(recursive: true);
    _dir = d;
    return d;
  }

  /// The app's private data folder, found without any plugin.
  /// On Android the system temp dir is <data>/cache, so its parent is the
  /// app's own data directory (/data/user/0/<package>). Same folder that
  /// path_provider's "documents" directory uses (app_flutter).
  static String _appDataDir() {
    for (final base in ['/data/user/0/com.yash.walkfit', '/data/data/com.yash.walkfit']) {
      if (Platform.isAndroid && Directory(base).existsSync()) return '$base/app_flutter';
    }
    final tmp = Directory.systemTemp.path;
    if (Platform.isAndroid && tmp.endsWith('/cache')) {
      return '${Directory(tmp).parent.path}/app_flutter';
    }
    return tmp;
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
