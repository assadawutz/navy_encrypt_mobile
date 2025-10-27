import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env._();

  static const _defaultApiBaseUrl = 'https://navenc.navy.mi.th/navy-api';
  static const _defaultEnvironment = 'development';
  static const _defaultReleaseChannel = 'internal';

  static String get environment {
    final value = dotenv.maybeGet('APP_ENV');
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return _defaultEnvironment;
  }

  static String get navyApiBaseUrl {
    final value = dotenv.maybeGet('NAVY_API_BASE_URL');
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return _defaultApiBaseUrl;
  }

  static String get releaseChannel {
    final value = dotenv.maybeGet('RELEASE_CHANNEL');
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    return _defaultReleaseChannel;
  }

  static String get androidSigningStoreFile {
    final value = dotenv.maybeGet('ANDROID_KEYSTORE_PATH');
    return value?.trim();
  }

  static String get androidSigningStorePassword {
    final value = dotenv.maybeGet('ANDROID_KEYSTORE_PASSWORD');
    return value?.trim();
  }

  static String get androidSigningKeyAlias {
    final value = dotenv.maybeGet('ANDROID_KEY_ALIAS');
    return value?.trim();
  }

  static String get androidSigningKeyPassword {
    final value = dotenv.maybeGet('ANDROID_KEY_PASSWORD');
    return value?.trim();
  }

  static String get iosBundleIdentifier {
    final value = dotenv.maybeGet('IOS_BUNDLE_IDENTIFIER');
    return value?.trim();
  }

  static String get iosTeamId {
    final value = dotenv.maybeGet('IOS_TEAM_ID');
    return value?.trim();
  }

  static String get windowsPublisherId {
    final value = dotenv.maybeGet('WINDOWS_PUBLISHER_ID');
    return value?.trim();
  }
}
