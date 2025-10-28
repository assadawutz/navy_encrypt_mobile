import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class PlatformGuardException implements Exception {
  final String message;

  const PlatformGuardException(this.message);

  @override
  String toString() => message;
}

class PlatformGuard {
  const PlatformGuard._();

  static const _supportedMessage = 'แพลตฟอร์มนี้ยังไม่รองรับ';

  static bool get _isDesktop => Platform.isWindows || Platform.isMacOS;
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

  static void ensureSafeFilePath(String path) {
    if (path == null || path.trim().isEmpty) {
      throw const PlatformGuardException('ไม่พบไฟล์');
    }

    final trimmed = path.trim();
    final context = Platform.isWindows
        ? p.Context(style: p.Style.windows)
        : p.Context(style: p.Style.posix);
    final normalized = context.normalize(trimmed);

    if (!context.isAbsolute(normalized)) {
      throw const PlatformGuardException('ไม่สามารถเข้าถึงไฟล์ได้');
    }

    final segments = context.split(normalized);
    if (segments.any((segment) => segment == '..')) {
      throw const PlatformGuardException('ไม่สามารถเข้าถึงไฟล์ได้');
    }

    if (Platform.isWindows) {
      final hasDrive = normalized.contains(':');
      if (!hasDrive) {
        throw const PlatformGuardException('ไม่สามารถเข้าถึงไฟล์ได้');
      }
    }
  }
}
