import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermGuard {
  const PermGuard._();

  static Future<void> ensure() async {
    final permissions = _defaultPermissions();
    if (permissions.isEmpty) {
      return;
    }
    await _requestPermissions(permissions);
  }

  static Future<bool> ensurePickerAccess({
    bool images = true,
    bool videos = true,
  }) async {
    final permissions = _pickerPermissions(images: images, videos: videos);
    if (permissions.isEmpty) {
      return true;
    }
    return _requestPermissions(permissions);
  }

  static Future<bool> ensureCameraAccess() async {
    final permissions = _cameraPermissions();
    if (permissions.isEmpty) {
      return true;
    }
    return _requestPermissions(permissions);
  }

  static Set<Permission> _defaultPermissions() {
    if (Platform.isAndroid) {
      return {
        Permission.photos,
        Permission.videos,
        Permission.storage,
        Permission.camera,
      };
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return {Permission.photos, Permission.camera};
    }

    return <Permission>{};
  }

  static Set<Permission> _pickerPermissions({
    bool images = true,
    bool videos = true,
  }) {
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

    return permissions;
  }

  static Set<Permission> _cameraPermissions() {
    final permissions = <Permission>{Permission.camera};
    if (Platform.isIOS || Platform.isAndroid) {
      permissions.add(Permission.microphone);
    }
    return permissions;
  }

  static Future<bool> _requestPermissions(Set<Permission> permissions) async {
    if (permissions == null || permissions.isEmpty) {
      return true;
    }

    final statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }
}
