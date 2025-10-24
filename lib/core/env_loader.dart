import 'dart:convert';

class EnvConfig {
  EnvConfig._(this._values);

  static EnvConfig _instance;

  final Map<String, String> _values;

  static Future<EnvConfig> load() async {
    if (_instance != null) {
      return _instance;
    }
    final Map<String, String> values = {};
    _mergeConfig(values, _decodeFromDartDefine());
    _instance = EnvConfig._(values);
    return _instance;
  }

  String get(String key, {String fallback}) {
    return _values[key] ?? fallback;
  }

  static Map<String, String> _decodeFromDartDefine() {
    const encoded = String.fromEnvironment('APP_CONFIG_BASE64');
    if (encoded.isEmpty) {
      return const {};
    }
    try {
      final raw = utf8.decode(base64.decode(encoded));
      return _parse(raw);
    } catch (_) {
      return const {};
    }
  }

  static void _mergeConfig(
    Map<String, String> target,
    Map<String, String> candidate,
  ) {
    if (candidate == null || candidate.isEmpty) {
      return;
    }
    target.addAll(candidate);
  }

  static Map<String, String> _parse(String raw) {
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    final Map<String, String> values = {};
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
    return values;
  }
}
