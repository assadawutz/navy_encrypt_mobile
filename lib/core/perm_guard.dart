import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermGuard {
  const PermGuard._();

  static Future<void> ensure() async {
    if (Platform.isAndroid) {
      await [Permission.photos, Permission.videos, Permission.storage, Permission.camera].request();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await [Permission.photos, Permission.camera].request();
    }
  }

  static Future<bool> ensurePickerAccess({
    bool images = true,
    bool videos = true,
  }) async {
    final permissions = <Permission>{};

    if (Platform.isAndroid) {
      if (images) {
        permissions.add(Permission.photos);
      }
      if (videos) {
        permissions.add(Permission.videos);
      }
      permissions.add(Permission.storage);
    } else if (Platform.isIOS) {
      if (images) {
        permissions.add(Permission.photos);
      }
      if (videos) {
        permissions.add(Permission.photosAddOnly);
      }
    } else if (Platform.isMacOS) {
      if (images) {
        permissions.add(Permission.photos);
      }
    }

    if (permissions.isEmpty) {
      return true;
    }

    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  static Future<bool> ensureCameraAccess() async {
    final permissions = <Permission>{Permission.camera};
    if (Platform.isIOS || Platform.isAndroid) {
      permissions.add(Permission.microphone);
    }
    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }
}
