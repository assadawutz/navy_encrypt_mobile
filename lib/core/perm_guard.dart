import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// จัดการ permission ให้รองรับ Android 13+/iOS Photos แบบรวมศูนย์
class PermGuard {
  PermGuard._();

  static Future<bool> ensurePickerAccess() async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return true;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkInt();
      if (sdkInt >= 33) {
        final results = await <Permission>{
          Permission.photos,
          Permission.videos,
          Permission.audio,
        }.request();
        return results.values.any((status) => status.isGranted);
      }

      final storage = await Permission.storage.request();
      if (storage.isGranted) {
        return true;
      }

      final manage = await Permission.manageExternalStorage.request();
      return manage.isGranted;
    }

    return true;
  }

  static Future<bool> ensureMediaWriteAccess() async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return true;
    }

    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      return status.isGranted || status.isLimited;
    }

    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkInt();
      if (sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      }

      final storage = await Permission.storage.request();
      if (storage.isGranted) {
        return true;
      }
      final manage = await Permission.manageExternalStorage.request();
      return manage.isGranted;
    }

    return true;
  }

  static Future<int> _androidSdkInt() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt ?? 30;
  }
}
