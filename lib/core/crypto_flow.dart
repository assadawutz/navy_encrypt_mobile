import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:navy_encrypt/core/io_helper.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:navy_encrypt/services/api.dart';
import 'package:navy_encrypt/storage/prefs.dart';
import 'package:path/path.dart' as p;

class CryptoFlowException implements Exception {
  final String message;
  CryptoFlowException(this.message);

  @override
  String toString() => message ?? 'CryptoFlowException';
}

typedef CryptoProgressCallback = void Function(String message);

class CryptoResult {
  final File file;
  final bool didEncrypt;
  final bool didWatermark;
  final bool didDecrypt;
  final bool unauthorized;
  final String message;
  final Map<String, dynamic> resultArguments;
  final String logId;
  final String uuid;
  final String signatureCode;

  CryptoResult({
    this.file,
    this.didEncrypt = false,
    this.didWatermark = false,
    this.didDecrypt = false,
    this.unauthorized = false,
    this.message,
    this.resultArguments,
    this.logId,
    this.uuid,
    this.signatureCode,
  });

  bool get isSuccess => file != null && !unauthorized;
}

class CryptoFlow {
  CryptoFlow._();

  static const int maxFileSizeInBytes = 20 * 1024 * 1024;

  static Future<File> validateEncryptionSource(String path) async {
    final file = await _validateFile(path);
    if (p.extension(file.path).toLowerCase() == '.enc') {
      throw CryptoFlowException('ไฟล์นี้ถูกเข้ารหัสแล้ว');
    }
    return file;
  }

  static Future<File> validateDecryptionSource(String path) async {
    final file = await _validateFile(path);
    if (p.extension(file.path).toLowerCase() != '.enc') {
      throw CryptoFlowException('ไฟล์ต้องมีนามสกุล .enc');
    }
    return file;
  }

  static Future<File> validateExistingSource(String path) async {
    return _validateFile(path);
  }

  static Future<File> ensureFromBytes({
    String path,
    Uint8List bytes,
    String fallbackName,
  }) async {
    final file = await IOHelper.ensureFile(
      path: path,
      bytes: bytes,
      fallbackName: fallbackName,
    );
    if (file == null) {
      throw CryptoFlowException('ไม่พบไฟล์');
    }
    return file;
  }

  static Future<CryptoResult> runEncryption({
    @required BuildContext context,
    @required String sourcePath,
    String watermark,
    @required BaseAlgorithm algorithm,
    String password,
    CryptoProgressCallback onProgress,
  }) async {
    final trimmedWatermark = watermark?.trim();
    final bool doWatermark = trimmedWatermark?.isNotEmpty == true;
    final bool doEncrypt = algorithm.code != Navec.notEncryptCode;

    final file = doEncrypt
        ? await validateEncryptionSource(sourcePath)
        : await validateExistingSource(sourcePath);

    File workingFile = await IOHelper.duplicateToTemp(file);
    if (workingFile == null) {
      throw CryptoFlowException('ไม่สามารถคัดลอกไฟล์ได้');
    }

    String signatureCode;
    String uuid;

    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();

    if (doWatermark) {
      onProgress?.call('กำลังใส่ลายน้ำ');
      try {
        signatureCode = await MyApi().getWatermarkSignatureCode(email, secret);
      } catch (error) {
        throw CryptoFlowException('เกิดข้อผิดพลาด: ${error.toString()}');
      }
      signatureCode ??= trimmedWatermark;

      final watermarkedFile = await Navec.addWatermark(
        context: context,
        filePath: workingFile.path,
        message: trimmedWatermark,
        email: email ?? '',
        signatureCode: signatureCode,
      );

      if (watermarkedFile == null) {
        throw CryptoFlowException('เกิดข้อผิดพลาด: ไม่สามารถใส่ลายน้ำได้');
      }

      workingFile = await _renameWithPattern(
        watermarkedFile,
        'file_watermarked',
        p.extension(watermarkedFile.path),
      );
    }

    if (doEncrypt) {
      final refCode = await MyPrefs.getRefCode();
      try {
        uuid = await MyApi().getUuid(refCode);
      } catch (error) {
        throw CryptoFlowException('เกิดข้อผิดพลาด: ${error.toString()}');
      }

      if (uuid == null || uuid.trim().isEmpty) {
        throw CryptoFlowException('ไม่สามารถเข้ารหัสได้');
      }

      onProgress?.call('กำลังเข้ารหัส');

      final encryptedFile = await Navec.encryptFile(
        filePath: workingFile.path,
        password: password?.trim(),
        algo: algorithm,
        uuid: uuid,
      );

      if (encryptedFile == null) {
        throw CryptoFlowException('เกิดข้อผิดพลาด: ไม่สามารถเข้ารหัสไฟล์ได้');
      }

      workingFile = await _renameWithPattern(
        encryptedFile,
        'file_encrypted',
        '.${Navec.encryptedFileExtension}',
      );
    }

    String logId;
    try {
      if (workingFile != null) {
        final fileName = p.basename(workingFile.path);
        final type = doEncrypt ? 'encryption' : 'watermark';
        final result = await MyApi().saveLog(
          email,
          fileName,
          uuid,
          signatureCode,
          'create',
          type,
          secret,
          null,
        );
        if (result == null) {
          throw CryptoFlowException('ไม่สามารถบันทึกข้อมูลได้');
        }
        logId = result.toString();
      }
    } catch (error) {
      throw CryptoFlowException('เกิดข้อผิดพลาด: ${error.toString()}');
    }

    final message = buildSuccessMessage(
      didWatermark: doWatermark,
      didEncrypt: doEncrypt,
    );

    final arguments = buildResultArguments(
      file: workingFile,
      message: message,
      isEncryption: doEncrypt,
      userId: logId,
      signatureCode: signatureCode,
      type: doEncrypt ? 'encryption' : 'watermark',
    );

    return CryptoResult(
      file: workingFile,
      didEncrypt: doEncrypt,
      didWatermark: doWatermark,
      message: message,
      resultArguments: arguments,
      logId: logId,
      uuid: uuid,
      signatureCode: signatureCode,
    );
  }

  static Future<CryptoResult> runDecryption({
    @required BuildContext context,
    @required String sourcePath,
    @required String password,
  }) async {
    final file = await validateDecryptionSource(sourcePath);

    List decryptData;
    try {
      decryptData = await Navec.decryptFile(
        context: context,
        filePath: file.path,
        password: password,
      );
    } catch (error) {
      throw CryptoFlowException('เกิดข้อผิดพลาด: ${error.toString()}');
    }

    File outFile = decryptData[0];
    final String uuid = decryptData[1];

    if (outFile == null || uuid == null) {
      throw CryptoFlowException('เกิดข้อผิดพลาด: ไม่สามารถถอดรหัสไฟล์ได้');
    }

    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();

    bool isAuthorized = true;
    try {
      isAuthorized = await MyApi().getCheckDecrypt(email, uuid);
    } catch (error) {
      throw CryptoFlowException('เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์!');
    }

    if (!isAuthorized) {
      await outFile.delete().catchError((_) {});
      return CryptoResult(
        didDecrypt: false,
        unauthorized: true,
        uuid: uuid,
      );
    }

    outFile = await _renameWithPattern(
      outFile,
      'file_decrypted',
      p.extension(outFile.path),
    );

    String logId;
    try {
      final fileName = p.basename(sourcePath);
      final result = await MyApi().saveLog(
        email,
        fileName,
        uuid,
        null,
        'view',
        'decryption',
        secret,
        null,
      );
      if (result == null) {
        throw CryptoFlowException('ไม่สามารถบันทึกข้อมูลได้');
      }
      logId = result.toString();
    } catch (error) {
      throw CryptoFlowException('เกิดข้อผิดพลาด: ${error.toString()}');
    }

    const message = 'ถอดรหัสสำเร็จ';
    final arguments = buildResultArguments(
      file: outFile,
      message: message,
      isEncryption: false,
      userId: logId,
      signatureCode: null,
      type: 'decryption',
    );

    return CryptoResult(
      file: outFile,
      didDecrypt: true,
      message: message,
      resultArguments: arguments,
      logId: logId,
      uuid: uuid,
    );
  }

  static String buildSuccessMessage({
    bool didWatermark,
    bool didEncrypt,
  }) {
    var message = '';
    if (didWatermark == true) {
      message = 'ใส่ลายน้ำ';
    }
    if (didEncrypt == true) {
      message = '${message.isEmpty ? '' : '$messageและ'}เข้ารหัส';
    }
    if (message.isEmpty) {
      message = 'ดำเนินการ';
    }
    return '$messageสำเร็จ';
  }

  static Map<String, dynamic> buildResultArguments({
    @required File file,
    @required String message,
    @required bool isEncryption,
    String userId,
    String signatureCode,
    String type,
  }) {
    return {
      'filePath': file?.path,
      'message': message,
      'userID': userId,
      'isEncryption': isEncryption,
      'fileEncryptPath': file?.path,
      'signatureCode': signatureCode,
      'type': type ?? (isEncryption ? 'encryption' : 'decryption'),
    };
  }

  static Future<File> _validateFile(String path) async {
    if (path == null || path.trim().isEmpty) {
      throw CryptoFlowException('ไม่พบไฟล์');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw CryptoFlowException('ไม่พบไฟล์');
    }
    final size = await file.length();
    if (size <= 0) {
      throw CryptoFlowException('ไม่พบไฟล์');
    }
    if (size > maxFileSizeInBytes) {
      throw CryptoFlowException('ไฟล์มีขนาดเกิน 20MB');
    }
    return file;
  }

  static Future<File> _renameWithPattern(
    File file,
    String prefix,
    String extension,
  ) async {
    final directory = p.dirname(file.path);
    final fileName = IOHelper.timestampedName(prefix, extension);
    final targetPath = p.join(directory, fileName);
    try {
      return await file.rename(targetPath);
    } catch (_) {
      final copiedFile = await file.copy(targetPath);
      await file.delete().catchError((_) {});
      return copiedFile;
    }
  }
}
