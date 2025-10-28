import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:navy_encrypt/core/perm_guard.dart';
import 'package:navy_encrypt/core/platform_guard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class IOHelperException implements Exception {
  final String message;

  const IOHelperException(this.message);

  @override
  String toString() => message;
}

class IOHelper {
  static const _workspaceFolderName = 'navy_encrypt_workspace';
  static const _resultFolderName = 'navy_encrypt_results';
  static const _documentsFolderName = 'navy_encrypt_documents';

  const IOHelper._();

  static Future<void> _ensureSupported() async {
    try {
      await PlatformGuard.ensureSupportedPlatform();
    } on PlatformGuardException catch (error) {
      throw IOHelperException(error.message);
    }
  }

  static Future<Directory> _ensureDirectory(String folderName) async {
    await _ensureSupported();

    try {
      Directory root;
      if (Platform.isAndroid) {
        final externalDirs = await getExternalStorageDirectories(
          type: StorageDirectory.documents,
        );
        root = (externalDirs != null && externalDirs.isNotEmpty)
            ? externalDirs.first
            : await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        root = await getApplicationDocumentsDirectory();
      } else if (Platform.isMacOS) {
        root = await getApplicationSupportDirectory();
      } else if (Platform.isWindows) {
        root = await (getDownloadsDirectory() ?? getApplicationDocumentsDirectory());
      } else {
        throw const IOHelperException('แพลตฟอร์มนี้ยังไม่รองรับ');
      }

      final directory = Directory(p.join(root.path, folderName));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } on IOHelperException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to resolve directory "$folderName": $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const IOHelperException('ไม่สามารถเข้าถึงโฟลเดอร์ปลายทางได้');
    }
  }

  static Future<Directory> ensureWorkspaceDir() async {
    if (Platform.isAndroid) {
      await PermGuard.ensure();
    }
    return _ensureDirectory(_workspaceFolderName);
  }

  static Future<Directory> ensureResultDir() async {
    return _ensureDirectory(_resultFolderName);
  }

  static Future<Directory> ensureDocDir() async {
    return _ensureDirectory(_documentsFolderName);
  }

  static Future<File> saveBytes(String filename, List<int> bytes,
      {bool toResultDirectory = false}) async {
    if (bytes == null || bytes.isEmpty) {
      throw const IOHelperException('ไม่พบข้อมูลไฟล์');
    }

    final sanitizedName = _sanitizeFileName(filename) ??
        'file_${DateTime.now().millisecondsSinceEpoch}';

    final targetDirectory =
        toResultDirectory ? await ensureResultDir() : await ensureWorkspaceDir();
    final file = File(p.join(targetDirectory.path, sanitizedName));

    return _writeBytesSafely(file, bytes);
  }

  static Future<File> copyToWorkspace(File source) async {
    if (source == null) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    try {
      try {
        PlatformGuard.ensureSafeFilePath(source.path);
      } on PlatformGuardException catch (error) {
        throw IOHelperException(error.message);
      }

      if (!await source.exists()) {
        throw const IOHelperException('ไม่พบไฟล์');
      }

      final workspace = await ensureWorkspaceDir();
      final sanitizedName = _sanitizeFileName(p.basename(source.path)) ??
          'file_${DateTime.now().millisecondsSinceEpoch}${p.extension(source.path)}';

      File destination = File(p.join(workspace.path, sanitizedName));
      if (await destination.exists()) {
        destination = await _deduplicate(destination);
      }

      try {
        final copied = await source.copy(destination.path);
        return copied;
      } on FileSystemException catch (error, stackTrace) {
        debugPrint('❌ Failed to copy file to workspace: $error');
        debugPrintStack(stackTrace: stackTrace);
        throw const IOHelperException('ไม่สามารถคัดลอกไฟล์ไปยังพื้นที่ทำงานได้');
      }
    } on IOHelperException {
      rethrow;
    }
  }

  static Future<File> renameWithTimestamp(
    File file, {
    String prefix,
    String extension,
  }) async {
    if (file == null) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    try {
      try {
        PlatformGuard.ensureSafeFilePath(file.path);
      } on PlatformGuardException catch (error) {
        throw IOHelperException(error.message);
      }

      if (!await file.exists()) {
        throw const IOHelperException('ไม่พบไฟล์');
      }

      final resultDir = await ensureResultDir();
      final sanitizedPrefix = _sanitizeFileName(prefix ?? 'file');
      final ext = extension ?? p.extension(file.path);
      final sanitizedExt = ext != null && ext.trim().isNotEmpty && ext.startsWith('.')
          ? ext
          : (ext != null && ext.trim().isNotEmpty ? '.${ext.trim()}' : '');

      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('-', '')
          .replaceAll('.', '');
      final targetPath = p.join(
        resultDir.path,
        '${sanitizedPrefix ?? 'file'}_${timestamp}${sanitizedExt}',
      );

      try {
        return await file.rename(targetPath);
      } on FileSystemException catch (error, stackTrace) {
        debugPrint('⚠️ Rename failed, fallback to copy: $error');
        debugPrintStack(stackTrace: stackTrace);
        try {
          final copied = await file.copy(targetPath);
          await file.delete().catchError((_) {});
          return copied;
        } on FileSystemException catch (copyError, copyStackTrace) {
          debugPrint('❌ Copy fallback failed: $copyError');
          debugPrintStack(stackTrace: copyStackTrace);
          throw const IOHelperException('ไม่สามารถย้ายไฟล์ไปยังปลายทางได้');
        }
      }
    } on IOHelperException {
      rethrow;
    }
  }

  static Future<File> resolveInput({
    String path,
    List<int> bytes,
    String fallbackName,
  }) async {
    await _ensureSupported();

    if ((path == null || path.trim().isEmpty) &&
        (bytes == null || bytes.isEmpty)) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    if (path != null && path.trim().isNotEmpty) {
      try {
        PlatformGuard.ensureSafeFilePath(path);
      } on PlatformGuardException catch (error) {
        throw IOHelperException(error.message);
      }

      final original = File(path.trim());
      if (!await original.exists()) {
        throw const IOHelperException('ไม่พบไฟล์');
      }
      return copyToWorkspace(original);
    }

    final sanitizedName = _sanitizeFileName(fallbackName) ??
        'file_${DateTime.now().millisecondsSinceEpoch}';
    return saveBytes(sanitizedName, bytes);
  }

  static Future<void> preview(File file) async {
    await _ensureSupported();

    if (file == null) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    try {
      PlatformGuard.ensureSafeFilePath(file.path);
    } on PlatformGuardException catch (error) {
      throw IOHelperException(error.message);
    }

    if (!await file.exists()) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    final result = await OpenFilex.open(file.path);
    if (result.type == ResultType.noAppToOpen) {
      throw const IOHelperException('ไม่พบแอปที่ใช้เปิดไฟล์ประเภทนี้');
    }
  }

  static Future<void> shareFile(File file) async {
    await _ensureSupported();

    if (file == null) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    try {
      PlatformGuard.ensureSafeFilePath(file.path);
    } on PlatformGuardException catch (error) {
      throw IOHelperException(error.message);
    }

    if (!await file.exists()) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    if (PlatformGuard.canUseShareSheet) {
      await Share.shareXFiles([XFile(file.path)]);
      return;
    }

    if (Platform.isWindows) {
      final arguments = ['/select,', file.path];
      try {
        await Process.run('explorer', arguments);
      } catch (error) {
        throw IOHelperException(
            'ไม่สามารถเปิด File Explorer ได้: ${error.toString()}');
      }
      return;
    }

    throw const IOHelperException('ไม่รองรับการแชร์ไฟล์บนแพลตฟอร์มนี้');
  }

  static String _sanitizeFileName(String value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    final sanitized = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.isEmpty ? null : sanitized;
  }

  static Future<File> _deduplicate(File file) async {
    final dir = file.parent;
    final baseName = p.basenameWithoutExtension(file.path);
    final ext = p.extension(file.path);
    var counter = 1;
    while (await file.exists()) {
      final candidate = File(p.join(dir.path, '${baseName}_$counter$ext'));
      if (!await candidate.exists()) {
        return candidate;
      }
      counter++;
    }
    return file;
  }

  static Future<void> tryDelete(File file) async {
    if (file == null) {
      return;
    }

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      debugPrint('⚠️ Failed to delete file ${file.path}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<File> _writeBytesSafely(File target, List<int> bytes) async {
    final tempPath = '${target.path}.tmp';
    final tempFile = File(tempPath);

    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final written = await tempFile.writeAsBytes(bytes, flush: true);
      final actualLength = await written.length();
      if (actualLength != bytes.length) {
        await written.delete().catchError((_) {});
        throw const IOHelperException('ไม่สามารถบันทึกไฟล์ได้');
      }

      try {
        await written.rename(target.path);
        return File(target.path);
      } on FileSystemException {
        final copied = await written.copy(target.path);
        await written.delete().catchError((_) {});
        return copied;
      }
    } on IOHelperException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to write file ${target.path}: $error');
      debugPrintStack(stackTrace: stackTrace);
      await tempFile.delete().catchError((_) {});
      throw const IOHelperException('ไม่สามารถบันทึกไฟล์ได้ (พื้นที่ไม่พอหรือสิทธิ์ไม่เพียงพอ)');
    }
  }
}
