import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class IOHelper {
  IOHelper._();

  static const String _docDirName = 'navec';
  static final Uuid _uuid = Uuid();
  static Directory _cachedDocDir;

  static Future<Directory> ensureDocDir() async {
    if (_cachedDocDir != null) {
      return _cachedDocDir;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(appDocDir.path, _docDirName));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    _cachedDocDir = target;
    return target;
  }

  static Future<Directory> ensureTempDir({String child, bool unique = false}) async {
    final base = await getTemporaryDirectory();
    if (child == null && !unique) {
      return base;
    }

    final dirName = child ?? _uuid.v1();
    final target = Directory(p.join(base.path, unique ? _uuid.v4() : dirName));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  static Future<File> persistBytes({
    @required String fileName,
    @required Uint8List bytes,
    bool uniqueSubDir = true,
    bool useDocDir = false,
  }) async {
    assert(fileName != null && fileName.trim().isNotEmpty);
    assert(bytes != null && bytes.isNotEmpty);

    final Directory directory;
    if (useDocDir) {
      directory = await ensureDocDir();
    } else {
      directory = await ensureTempDir(unique: uniqueSubDir);
    }

    final target = File(p.join(directory.path, fileName));
    return target.writeAsBytes(bytes, flush: true);
  }

  static Future<File> ensureFile({
    String path,
    Uint8List bytes,
    String fallbackName,
    bool useDocDir = false,
  }) async {
    if (path != null && path.trim().isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }

    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final resolvedName = fallbackName ?? 'navy_${DateTime.now().millisecondsSinceEpoch}';
    return persistBytes(
      fileName: resolvedName,
      bytes: bytes,
      useDocDir: useDocDir,
    );
  }

  static Future<File> duplicateToTemp(File source, {String fileName}) async {
    if (source == null || !await source.exists()) {
      return null;
    }

    final directory = await ensureTempDir(unique: true);
    final targetPath = p.join(directory.path, fileName ?? p.basename(source.path));
    return source.copy(targetPath);
  }

  static Future<File> copyToWorkspace(File source, {String fileName}) async {
    if (source == null || !await source.exists()) {
      return null;
    }

    final docDir = await ensureDocDir();
    final targetName = fileName ?? p.basename(source.path);
    final targetPath = p.join(docDir.path, targetName);
    return source.copy(targetPath);
  }

  static String timestampedName(String prefix, String extension) {
    final safeExtension = extension?.isNotEmpty == true
        ? (extension.startsWith('.') ? extension : '.$extension')
        : '';
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}$safeExtension';
  }
}
