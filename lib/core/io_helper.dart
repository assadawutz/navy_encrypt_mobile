import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../etc/file_util.dart';

/// รวม helper ด้านไฟล์เพื่อให้ flow เข้ารหัส/ถอดรหัสเรียกใช้ได้ทุกแพลตฟอร์ม
class IOHelper {
  IOHelper._();

  /// สร้างไฟล์บนดิสก์จาก [PlatformFile] ไม่ว่าจะมาจาก path เดิมหรือ memory bytes
  static Future<File> persistPlatformFile(PlatformFile platformFile) async {
    if (platformFile == null) {
      throw ArgumentError('PlatformFile is required.');
    }

    final existingPath = platformFile.path;
    if (existingPath != null && existingPath.trim().isNotEmpty) {
      final onDisk = File(existingPath);
      if (await onDisk.exists()) {
        return onDisk;
      }
    }

    final bytes = platformFile.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No bytes available for ${platformFile.name}.');
    }

    final safeName = platformFile.name?.trim().isNotEmpty == true
        ? platformFile.name
        : 'navec_${DateTime.now().millisecondsSinceEpoch}';
    return writeBytesToTemp(Uint8List.fromList(bytes), fileName: safeName);
  }

  /// เขียน bytes ลง temp directory และคืนค่าไฟล์ที่ได้
  static Future<File> writeBytesToTemp(Uint8List data, {String fileName}) async {
    if (data == null || data.isEmpty) {
      throw ArgumentError('Data must not be empty.');
    }

    final tempDir = await getTemporaryDirectory();
    final safeName = (fileName?.trim().isNotEmpty ?? false)
        ? fileName
        : 'navec_${DateTime.now().millisecondsSinceEpoch}';
    final target = File(p.join(tempDir.path, safeName));
    return target.writeAsBytes(data, flush: true);
  }

  /// รับประกันว่ามี documents directory สำหรับเก็บไฟล์ผลลัพธ์
  static Future<Directory> ensureAppDocumentsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(root.path, 'navec'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  /// คัดลอกไฟล์ไปยัง documents directory ของแอป
  static Future<File> copyToDocuments(File source) async {
    if (source == null) {
      throw ArgumentError('Source file must not be null.');
    }
    if (!await source.exists()) {
      throw FileSystemException('Source not found', source.path);
    }

    final docs = await ensureAppDocumentsDir();
    final targetPath = p.join(docs.path, p.basename(source.path));
    return source.copy(targetPath);
  }

  /// รับประกันว่าพบไฟล์จาก path หรือ fallback bytes
  static Future<File> ensureFile(String path, {Uint8List fallbackBytes}) async {
    if (path != null && path.trim().isNotEmpty) {
      final candidate = File(path);
      if (await candidate.exists()) {
        return candidate;
      }
    }

    if (fallbackBytes != null && fallbackBytes.isNotEmpty) {
      return writeBytesToTemp(fallbackBytes,
          fileName: 'navec_${DateTime.now().millisecondsSinceEpoch}');
    }

    throw FileSystemException('Unable to materialize file.', path);
  }

  /// สร้างสำเนาไฟล์ใน temp เพื่อใช้เป็น workspace
  static Future<File> createWorkspaceCopy(String path) async {
    final materialized = await ensureFile(path);
    final tempDir = await FileUtil.createUniqueTempDir();
    final target = File(p.join(tempDir.path, p.basename(materialized.path)));
    return materialized.copy(target.path);
  }
}
