import 'dart:io';

import 'package:flutter/foundation.dart';

class PlatformGuardException implements Exception {
  final String message;

  const PlatformGuardException(this.message);

  @override
  String toString() => message;
}

class PlatformGuard {
  const PlatformGuard._();

  static const _supportedMessage = 'แพลตฟอร์มนี้ยังไม่รองรับ';

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get _isSupported => !_isWeb && (_isDesktop || _isMobile);

  static bool get _isWeb => kIsWeb;

  static Future<void> ensureSupportedPlatform() async {
    if (!_isSupported) {
      throw const PlatformGuardException(_supportedMessage);
    }
  }

  static bool get canUseShareSheet => Platform.isAndroid || Platform.isIOS;

  static String describeCurrentPlatform() {
    if (_isWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }
}
