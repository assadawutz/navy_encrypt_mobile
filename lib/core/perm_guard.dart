import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
class PermGuard {
  static Future<void> ensure() async {
    if (Platform.isAndroid) {
      await [Permission.photos, Permission.videos, Permission.storage, Permission.camera].request();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await [Permission.photos, Permission.camera].request();
    }
  }
}
