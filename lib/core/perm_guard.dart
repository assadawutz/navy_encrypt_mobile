import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermGuard {
  const PermGuard._();

  static bool _isPermissionGranted(PermissionStatus status) {
    if (status == null) {
      return false;
    }
    return status.isGranted || status.isLimited;
  }

  static Future<bool> _requestPermission(Permission permission) async {
    try {
      final currentStatus = await permission.status;
      if (_isPermissionGranted(currentStatus)) {
        return true;
      }
      final result = await permission.request();
      return _isPermissionGranted(result);
    } catch (error, stackTrace) {
      debugPrint('❌ Permission request failed for $permission: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static Future<bool> ensurePickerAccess({
    bool images = true,
    bool videos = true,
    bool audio = true,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    if (Platform.isIOS) {
      return _requestPermission(Permission.photos);
    }

    if (!Platform.isAndroid) {
      return true;
    }

    int sdkInt;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      sdkInt = androidInfo.version.sdkInt;
    } catch (error, stackTrace) {
      debugPrint('⚠️ Unable to resolve Android SDK version: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (sdkInt != null && sdkInt >= 33) {
      final requests = <Future<PermissionStatus>>[];
      if (images) {
        requests.add(Permission.photos.request());
      }
      if (videos) {
        requests.add(Permission.videos.request());
      }
      if (audio) {
        requests.add(Permission.audio.request());
      }

      if (requests.isNotEmpty) {
        final results = await Future.wait(requests);
        if (results.any(_isPermissionGranted)) {
          return true;
        }
      }
    }

    final fallbackPermissions = <Permission>[
      if (sdkInt != null && sdkInt >= 30) Permission.manageExternalStorage,
      Permission.storage,
    ];

    for (final permission in fallbackPermissions) {
      if (await _requestPermission(permission)) {
        return true;
      }
    }

    return false;
  }
}
