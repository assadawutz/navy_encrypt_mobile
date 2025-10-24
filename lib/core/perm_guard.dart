import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermGuard {
  PermGuard._();

  static int _cachedAndroidSdkInt;

  static bool _granted(PermissionStatus status) {
    return status != null && (status.isGranted || status.isLimited);
  }

  static Future<int> _resolveAndroidSdkInt() async {
    if (!Platform.isAndroid) {
      return null;
    }
    if (_cachedAndroidSdkInt != null) {
      return _cachedAndroidSdkInt;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cachedAndroidSdkInt = info.version.sdkInt;
      return _cachedAndroidSdkInt;
    } catch (error) {
      debugPrint('⚠️ อ่าน Android SDK ไม่สำเร็จ: $error');
      return null;
    }
  }

  static Future<bool> ensureMediaAccess({
    bool pickImage = false,
    bool pickVideo = false,
    bool forCamera = false,
  }) async {
    final requests = <Permission>{};

    if (Platform.isAndroid) {
      if (forCamera) {
        requests.add(Permission.camera);
      }

      final sdkInt = await _resolveAndroidSdkInt();
      if (sdkInt != null && sdkInt >= 33) {
        if (pickImage || !pickVideo) {
          requests.add(Permission.photos);
        }
        if (pickVideo || !pickImage) {
          requests.add(Permission.videos);
        }
        if (pickVideo) {
          requests.add(Permission.audio);
        }
      } else {
        requests.add(Permission.storage);
      }
    } else if (Platform.isIOS) {
      if (forCamera) {
        requests.add(Permission.camera);
      }
      if (pickImage || pickVideo) {
        requests.add(Permission.photos);
      }
    }

    if (requests.isEmpty) {
      return true;
    }

    final statuses = await Future.wait(
      requests.map((permission) async => await permission.request()),
    );
    return statuses.any(_granted);
  }

  static Future<bool> ensureFileSystemAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final status = await Permission.storage.request();
    if (_granted(status)) {
      return true;
    }
    final manageStatus = await Permission.manageExternalStorage.request();
    return _granted(manageStatus);
  }
}
