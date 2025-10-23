import 'package:flutter/services.dart' show rootBundle;

class EnvConfig {
  EnvConfig._(this._values);

  static EnvConfig _instance;

  final Map<String, String> _values;

  static Future<EnvConfig> load() async {
    if (_instance != null) {
      return _instance;
    }
    final Map<String, String> values = {};
    try {
      final raw = await rootBundle.loadString('.env');
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        final separatorIndex = trimmed.indexOf('=');
        if (separatorIndex == -1) {
          continue;
        }
        final key = trimmed.substring(0, separatorIndex).trim();
        final value = trimmed.substring(separatorIndex + 1).trim();
        if (key.isEmpty) {
          continue;
        }
        values[key] = value;
      }
    } catch (_) {
      // Fallback to empty config when the asset is missing.
    }
    _instance = EnvConfig._(values);
    return _instance;
  }

  String get(String key, {String fallback}) {
    return _values[key] ?? fallback;
  }
}
