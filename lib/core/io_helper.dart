import 'dart:async';
import 'dart:io';

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
    } else if (Platform.isLinux) {
      root = await getApplicationDocumentsDirectory();
    } else {
      throw const IOHelperException('แพลตฟอร์มนี้ยังไม่รองรับ');
    }

    final directory = Directory(p.join(root.path, folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<void> _ensureAndroidMediaAccess() async {
    if (!Platform.isAndroid) {
      return;
    }

    final granted = await PermGuard.ensurePickerAccess(
      images: true,
      videos: true,
      audio: true,
    );
    if (!granted) {
      throw const IOHelperException('ไม่สามารถเข้าถึงไฟล์สื่อได้');
    }
  }

  static Future<Directory> ensureWorkspaceDir() async {
    await _ensureAndroidMediaAccess();
    return _ensureDirectory(_workspaceFolderName);
  }

  static Future<Directory> ensureResultDir() async {
    await _ensureAndroidMediaAccess();
    return _ensureDirectory(_resultFolderName);
  }

  static Future<Directory> ensureDocDir() async {
    await _ensureAndroidMediaAccess();
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

    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<File> copyToWorkspace(File source) async {
    if (source == null) {
      throw const IOHelperException('ไม่พบไฟล์');
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

    return source.copy(destination.path);
  }

  static Future<File> renameWithTimestamp(
    File file, {
    String prefix,
    String extension,
  }) async {
    if (file == null || !await file.exists()) {
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
    } on FileSystemException {
      final copied = await file.copy(targetPath);
      await file.delete();
      return copied;
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

    String candidateName = fallbackName;
    if (path != null && path.trim().isNotEmpty) {
      final sanitizedPath = path.trim();
      final original = File(sanitizedPath);
      if (await original.exists()) {
        return copyToWorkspace(original);
      }
      candidateName ??= p.basename(sanitizedPath);
      if (bytes == null || bytes.isEmpty) {
        throw const IOHelperException('ไม่พบไฟล์');
      }
    }

    final sanitizedName = _sanitizeFileName(candidateName) ??
        'file_${DateTime.now().millisecondsSinceEpoch}';
    return saveBytes(sanitizedName, bytes);
  }

  static Future<void> preview(File file) async {
    await _ensureSupported();

    if (file == null || !await file.exists()) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    final result = await OpenFilex.open(file.path);
    if (result.type == ResultType.noAppToOpen) {
      throw const IOHelperException('ไม่พบแอปที่ใช้เปิดไฟล์ประเภทนี้');
    }
  }

  static Future<void> shareFile(File file) async {
    await _ensureSupported();

    if (file == null || !await file.exists()) {
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

    if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-R', file.path]);
      } catch (error) {
        throw IOHelperException('ไม่สามารถเปิด Finder ได้: ${error.toString()}');
      }
      return;
    }

    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [file.parent.path]);
      } catch (error) {
        throw IOHelperException(
            'ไม่สามารถเปิดไฟล์ในตัวจัดการไฟล์ได้: ${error.toString()}');
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
}
