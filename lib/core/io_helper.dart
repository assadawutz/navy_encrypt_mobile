import 'dart:io';
import 'dart:ui' show Rect;

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class IOHelperException implements Exception {
  final String message;

  const IOHelperException(this.message);

  @override
  String toString() => message;
}

class IOHelper {
  static const _docDirName = 'navec';
  static const _workspaceDirName = 'workspace';

  const IOHelper._();

  static Future<Directory> ensureTempDir() async {
    final tempDir = await getTemporaryDirectory();
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  static Future<Directory> ensureDocDir() async {
    final base = await getApplicationDocumentsDirectory();
    final docDir = Directory(p.join(base.path, _docDirName));
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    return docDir;
  }

  static Future<Directory> ensureWorkspaceDir() async {
    final docDir = await ensureDocDir();
    final workspace = Directory(p.join(docDir.path, _workspaceDirName));
    if (!await workspace.exists()) {
      await workspace.create(recursive: true);
    }
    return workspace;
  }

  static Future<File> persistBytes(
    String filename,
    List<int> bytes, {
    bool inWorkspace = true,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      throw const IOHelperException('ไม่พบข้อมูลไฟล์');
    }

    final sanitizedName = _resolveFileName(filename);
    final directory = inWorkspace ? await ensureWorkspaceDir() : await ensureTempDir();
    final target = await _createUniqueFile(directory, sanitizedName);
    return target.writeAsBytes(bytes, flush: true);
  }

  static Future<File> saveBytes(String filename, List<int> bytes) async {
    if (bytes == null || bytes.isEmpty) {
      throw const IOHelperException('ไม่พบข้อมูลไฟล์');
    }

    final sanitizedName = _resolveFileName(filename);
    final docDir = await getApplicationDocumentsDirectory();
    final target = await _createUniqueFile(docDir, sanitizedName);
    return target.writeAsBytes(bytes, flush: true);
  }

  static Future<File> copyToWorkspace(
    File source, {
    String preferredName,
  }) async {
    if (source == null) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    if (!await source.exists()) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    final workspace = await ensureWorkspaceDir();
    final sanitizedName = _resolveFileName(preferredName ?? p.basename(source.path));
    final destination = await _createUniqueFile(workspace, sanitizedName);
    return source.copy(destination.path);
  }

  static Future<File> resolveInput({
    String path,
    List<int> bytes,
    String fallbackName,
    bool shouldCopyToWorkspace = true,
  }) async {
    final trimmedPath = path?.trim();
    if (trimmedPath != null && trimmedPath.isNotEmpty) {
      final sourceFile = File(trimmedPath);
      if (await sourceFile.exists()) {
        return shouldCopyToWorkspace
            ? copyToWorkspace(sourceFile, preferredName: fallbackName)
            : sourceFile;
      }
    }

    if (bytes != null && bytes.isNotEmpty) {
      final name = fallbackName ??
          (trimmedPath != null && trimmedPath.isNotEmpty
              ? p.basename(trimmedPath)
              : 'navy_${DateTime.now().millisecondsSinceEpoch}');
      return persistBytes(name, bytes);
    }

    throw const IOHelperException('ไม่พบไฟล์');
  }

  static Future<File> copyToWorkspaceFile(
    File source, {
    String preferredName,
  }) =>
      copyToWorkspace(source, preferredName: preferredName);

  static Future<File> renameWithTimestamp(
    File file, {
    String prefix,
    String extension,
  }) async {
    if (file == null || !await file.exists()) {
      throw const IOHelperException('ไม่พบไฟล์');
    }

    final dir = p.dirname(file.path);
    final base = prefix?.trim().isNotEmpty == true ? prefix.trim() : 'file';
    final targetExtension = extension ?? p.extension(file.path);
    final newName = '${base}_${DateTime.now().millisecondsSinceEpoch}$targetExtension';
    final uniqueTarget = await _createUniqueFile(Directory(dir), newName);
    return file.rename(uniqueTarget.path);
  }

  static Future<File> _createUniqueFile(Directory directory, String fileName) async {
    if (directory == null) {
      throw const IOHelperException('ไม่พบโฟลเดอร์ปลายทาง');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final baseName = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);

    var candidate = fileName;
    var counter = 1;
    var candidateFile = File(p.join(directory.path, candidate));

    while (await candidateFile.exists()) {
      candidate = '${baseName}_$counter$extension';
      candidateFile = File(p.join(directory.path, candidate));
      counter++;
    }

    await candidateFile.create(recursive: true);
    return candidateFile;
  }

  static String _resolveFileName(String name) {
    final fallback = 'navy_${DateTime.now().millisecondsSinceEpoch}';
    final sanitized = name?.trim();
    if (sanitized == null || sanitized.isEmpty) {
      return '$fallback.bin';
    }
    final segments = sanitized.split(RegExp(r'[\\/]'));
    final lastSegment = segments.isEmpty ? fallback : segments.last;
    if (lastSegment.isEmpty) {
      return '$fallback.bin';
    }
    return lastSegment;
  }

  static Future<void> preview(File file) async {
    if (file == null) {
      throw const IOHelperException('ไม่พบไฟล์สำหรับเปิดดู');
    }
    await OpenFilex.open(file.path);
  }

  static Future<void> shareFile(
    File file, {
    Rect sharePositionOrigin,
  }) async {
    if (file == null) {
      throw const IOHelperException('ไม่พบไฟล์สำหรับแชร์');
    }
    if (!await file.exists()) {
      throw const IOHelperException('ไม่พบไฟล์สำหรับแชร์');
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
