import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PlatformGuardResult {
  final bool isReady;
  final String message;

  const PlatformGuardResult._(this.isReady, this.message);

  static const PlatformGuardResult ready = PlatformGuardResult._(true, '');

  factory PlatformGuardResult.blocked(String message) {
    return PlatformGuardResult._(false, message);
  }
}

class PlatformGuard {
  static Future<PlatformGuardResult> ensureInitialized() async {
    if (kIsWeb) {
      return PlatformGuardResult.blocked(
        'แอป Navy Encrypt ยังไม่รองรับการทำงานผ่านเว็บเบราว์เซอร์',
      );
    }

    if (Platform.isAndroid) {
      final permissionStatus = await _requestAndroidStoragePermission();
      if (!permissionStatus.isGranted) {
        return PlatformGuardResult.blocked(
          'ต้องอนุญาตสิทธิ์จัดการไฟล์ภายนอกใน Android ก่อนใช้งาน',
        );
      }
      return PlatformGuardResult.ready;
    }

    if (Platform.isIOS) {
      final success = await _validateSandboxWritable();
      if (!success) {
        return PlatformGuardResult.blocked(
          'ไม่สามารถใช้งาน sandbox ของ iOS ได้ โปรดลองรีสตาร์ทอุปกรณ์',
        );
      }
      return PlatformGuardResult.ready;
    }

    if (Platform.isWindows) {
      final success = await _validateWindowsStorage();
      if (!success) {
        return PlatformGuardResult.blocked(
          'ไม่สามารถเข้าถึงพื้นที่จัดเก็บท้องถิ่นของ Windows ได้',
        );
      }
      return PlatformGuardResult.ready;
    }

    return PlatformGuardResult.blocked('แพลตฟอร์มนี้ยังไม่รองรับ');
  }

  static Future<PermissionStatus> _requestAndroidStoragePermission() async {
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      return manageStatus;
    }

    if (manageStatus.isDenied || manageStatus.isLimited) {
      final requested = await Permission.manageExternalStorage.request();
      if (requested.isGranted) {
        return requested;
      }
    }

    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) {
      return storageStatus;
    }
    return await Permission.storage.request();
  }

  static Future<bool> _validateSandboxWritable() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final guardFile = File('${directory.path}/.navy_guard');
      await guardFile.writeAsString(DateTime.now().toIso8601String(), flush: true);
      await guardFile.delete();
      return true;
    } catch (error) {
      debugPrint('❌ iOS sandbox validation failed: $error');
      return false;
    }
  }

  static Future<bool> _validateWindowsStorage() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final guardFile = File('${directory.path}/navy_guard.txt');
      await guardFile.create(recursive: true);
      await guardFile.writeAsString('ready', flush: true);
      await guardFile.delete();
      return true;
    } catch (error) {
      debugPrint('❌ Windows storage validation failed: $error');
      return false;
    }
  }
}
