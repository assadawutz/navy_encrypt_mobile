import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class FileUtil {
  static Future<String> getTempDirPath() async {
    return (await getTemporaryDirectory()).path;
  }

  static Future<Directory> getDocDir() async {
    const docDirName = 'navec';

    final appDocDirPath = (await getApplicationDocumentsDirectory()).path;
    final myDocDirPath = '$appDocDirPath/$docDirName';
    final myDocDir = Directory(myDocDirPath);
    if (!await myDocDir.exists()) {
      await myDocDir.create();
    }


    return myDocDir;
  }


  static Future<String> getImageDirPath() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'Pictures');
      }
    }

    final appDocDirPath = (await getApplicationDocumentsDirectory()).path;
    return p.join(p.dirname(appDocDirPath), 'Pictures');
  }

  static Future<File> getTempFile(String name) async {
    final dir = await getTempDirPath();
    return File('$dir/$name');
  }

  static Future<File> createFileFromBytes(String name, Uint8List bytes) async {
    File file;
    try {
      file = await getTempFile(name);
      // ต้อง await เพื่อรอให้เขียนเสร็จก่อน ***
      file = await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      print(e);
    }
    return file;
  }

  static Future<Directory> createUniqueTempDir() async {
    var uuid = Uuid().v1();
    var dirPath = p.join(await getTempDirPath(), uuid);
    return Directory(dirPath)..createSync();
  }

  static void unzip({
    @required String dirPath,
    @required String filename,
    bool deleteZip = true,
  }) {
    // Read the Zip file from disk.
    final bytes = File('$dirPath/$filename').readAsBytesSync();

    // Decode the Zip file
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract the contents of the Zip archive to disk.
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File('$dirPath/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory('$dirPath/$filename')..createSync(recursive: true);
      }
    }

    if (deleteZip) {
      File('$dirPath/$filename').delete();
    }

    return;
  }

  static Future<String> getWindowsPicturesPath() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'Pictures');
      }
    }

    final appDocDirPath = (await getApplicationDocumentsDirectory()).path;
    return p.join(p.dirname(appDocDirPath), 'Pictures');
  }
}
