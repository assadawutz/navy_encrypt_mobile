import 'dart:async';

import 'runtime_env_stub.dart' if (dart.library.io) 'runtime_env_io.dart';

class EnvConfig {
  EnvConfig._(this._values);

  static EnvConfig _instance;

  final Map<String, String> _values;

  static Future<EnvConfig> load() {
    if (_instance != null) {
      return Future.value(_instance);
    }
    final Map<String, String> values = _loadValues();
    _instance = EnvConfig._(values);
    return Future.value(_instance);
  }

  static Map<String, String> _loadValues() {
    final Map<String, String> values = {};

    void putIfNotEmpty(String key, String value) {
      if (value != null) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          values[key] = trimmed;
        }
      }
    }

    const appDisplayName = String.fromEnvironment('APP_DISPLAY_NAME');
    const androidKeystorePath = String.fromEnvironment('ANDROID_KEYSTORE_PATH');
    const androidKeystorePassword =
        String.fromEnvironment('ANDROID_KEYSTORE_PASSWORD');
    const androidKeyPassword = String.fromEnvironment('ANDROID_KEY_PASSWORD');
    const androidKeyAlias = String.fromEnvironment('ANDROID_KEY_ALIAS');
    const iosCodeSignIdentity =
        String.fromEnvironment('IOS_CODE_SIGN_IDENTITY');
    const iosProvisioningProfile =
        String.fromEnvironment('IOS_PROVISIONING_PROFILE');
    const iosDevelopmentTeam =
        String.fromEnvironment('IOS_DEVELOPMENT_TEAM');
    const windowsPublisherDisplayName =
        String.fromEnvironment('WINDOWS_PUBLISHER_DISPLAY_NAME');
    const windowsCertificateSubject =
        String.fromEnvironment('WINDOWS_CERTIFICATE_SUBJECT');

    putIfNotEmpty('APP_DISPLAY_NAME', appDisplayName);
    putIfNotEmpty('ANDROID_KEYSTORE_PATH', androidKeystorePath);
    putIfNotEmpty('ANDROID_KEYSTORE_PASSWORD', androidKeystorePassword);
    putIfNotEmpty('ANDROID_KEY_PASSWORD', androidKeyPassword);
    putIfNotEmpty('ANDROID_KEY_ALIAS', androidKeyAlias);
    putIfNotEmpty('IOS_CODE_SIGN_IDENTITY', iosCodeSignIdentity);
    putIfNotEmpty('IOS_PROVISIONING_PROFILE', iosProvisioningProfile);
    putIfNotEmpty('IOS_DEVELOPMENT_TEAM', iosDevelopmentTeam);
    putIfNotEmpty(
        'WINDOWS_PUBLISHER_DISPLAY_NAME', windowsPublisherDisplayName);
    putIfNotEmpty('WINDOWS_CERTIFICATE_SUBJECT', windowsCertificateSubject);

    final runtimeEnv = loadRuntimeEnvironment();
    for (final entry in runtimeEnv.entries) {
      if (!values.containsKey(entry.key)) {
        putIfNotEmpty(entry.key, entry.value);
      }
    }

    return values;
  }

  String get(String key, {String fallback}) {
    return _values[key] ?? fallback;
  }
}
