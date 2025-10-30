import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:navy_encrypt/core/io_helper.dart';
import 'package:navy_encrypt/core/platform_guard.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:navy_encrypt/services/api.dart';
import 'package:navy_encrypt/storage/prefs.dart';
import 'package:path/path.dart' as p;

enum CryptoStep { validate, copy, watermark, encrypt, decrypt }

class CryptoFlowException implements Exception {
  final String message;

  const CryptoFlowException(this.message);

  @override
  String toString() => message;
}

class CryptoFlowUnauthorizedException extends CryptoFlowException {
  const CryptoFlowUnauthorizedException(String message) : super(message);
}

class CryptoFlowResult {
  final File file;
  final bool isEncryption;
  final String message;
  final Map<String, dynamic> payload;

  const CryptoFlowResult({
    @required this.file,
    @required this.isEncryption,
    @required this.message,
    this.payload = const {},
  });
}

class _CryptoFlowResultKeys {
  final String filePath = 'filePath';
  final String fileEncryptPath = 'fileEncryptPath';
  final String message = 'message';
  final String signatureCode = 'signatureCode';
  final String userID = 'userID';
  final String type = 'type';
  final String uuid = 'uuid';
  final String isEncryption = 'isEncryption';

  const _CryptoFlowResultKeys();
}

class CryptoFlow {
  static const int maxFileSizeInBytes = 20 * 1024 * 1024;

  static const Map<CryptoStep, String> messages = {
    CryptoStep.validate: 'กำลังตรวจสอบไฟล์',
    CryptoStep.copy: 'กำลังเตรียมไฟล์',
    CryptoStep.watermark: 'กำลังใส่ลายน้ำ',
    CryptoStep.encrypt: 'กำลังเข้ารหัส',
    CryptoStep.decrypt: 'กำลังถอดรหัส',
  };

  static const _CryptoFlowResultKeys resultKeys = _CryptoFlowResultKeys();

  const CryptoFlow._();

  static Future<void> validateFile(
    File file, {
    bool requireEncryptedExtension = false,
    bool forbidEncryptedExtension = false,
  }) async {
    if (file == null) {
      throw const CryptoFlowException('ไม่พบไฟล์');
    }

    try {
      PlatformGuard.ensureSafeFilePath(file.path);
    } on PlatformGuardException catch (error) {
      throw CryptoFlowException(error.message);
    }

    if (!await file.exists()) {
      throw const CryptoFlowException('ไม่พบไฟล์');
    }

    final length = await file.length();
    if (length <= 0) {
      throw const CryptoFlowException('ไม่พบไฟล์');
    }

    if (length > maxFileSizeInBytes) {
      throw const CryptoFlowException('ไฟล์มีขนาดเกิน 20MB');
    }

    final lowerExtension = p.extension(file.path).toLowerCase();
    if (requireEncryptedExtension && lowerExtension != '.enc') {
      throw const CryptoFlowException('ไฟล์ต้องมีนามสกุล .enc');
    }

    if (forbidEncryptedExtension && lowerExtension == '.enc') {
      throw const CryptoFlowException('ไฟล์นี้ถูกเข้ารหัสแล้ว');
    }
  }

  static Future<CryptoFlowResult> encrypt({
    @required BuildContext context,
    @required String filePath,
    @required BaseAlgorithm algorithm,
    @required String password,
    String watermark,
    void Function(String message) onMessage,
  }) async {
    if (filePath == null || filePath.trim().isEmpty) {
      throw const CryptoFlowException('ไม่พบไฟล์');
    }

    final source = File(filePath);
    await validateFile(source, forbidEncryptedExtension: algorithm.code != Navec.notEncryptCode);

    onMessage?.call(messages[CryptoStep.copy]);
    File processedFile;
    try {
      processedFile = await IOHelper.copyToWorkspace(source);
    } on IOHelperException catch (error) {
      throw CryptoFlowException(error.message);
    }

    final cleanupPaths = <String>{};
    void addCleanup(File file) {
      final path = file?.path;
      if (path != null && path.isNotEmpty) {
        cleanupPaths.add(path);
      }
    }

    void removeCleanup(File file) {
      final path = file?.path;
      if (path != null && path.isNotEmpty) {
        cleanupPaths.remove(path);
      }
    }

    addCleanup(processedFile);

    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();
    final refCode = await MyPrefs.getRefCode();

    String signatureCode;
    String uuid;
    var didWatermark = false;
    var didEncrypt = false;
    final trimmedWatermark = watermark?.trim();
    File renamedWatermark;
    File renamedEncrypted;

    try {
      if (trimmedWatermark?.isNotEmpty == true) {
        onMessage?.call(messages[CryptoStep.watermark]);
        signatureCode = await MyApi().getWatermarkSignatureCode(email, secret);
        signatureCode ??= trimmedWatermark;

        File watermarkedFile;
        try {
          watermarkedFile = await Navec.addWatermark(
            context: context,
            filePath: processedFile.path,
            message: trimmedWatermark,
            email: email ?? '',
            signatureCode: signatureCode,
          );
        } on FormatException catch (error) {
          throw CryptoFlowException(error.message ?? 'ไม่สามารถใส่ลายน้ำได้');
        }

        addCleanup(watermarkedFile);
        try {
          renamedWatermark = await IOHelper.renameWithTimestamp(
            watermarkedFile,
            prefix: 'file_watermarked',
            extension: p.extension(watermarkedFile.path),
          );
        } on IOHelperException catch (error) {
          throw CryptoFlowException(error.message);
        }
        addCleanup(renamedWatermark);
        removeCleanup(watermarkedFile);

        processedFile = renamedWatermark;
        didWatermark = true;
      }

      if (algorithm.code != Navec.notEncryptCode) {
        onMessage?.call(messages[CryptoStep.encrypt]);
        uuid = await _safeApiCall(() => MyApi().getUuid(refCode), 'ไม่สามารถเข้ารหัสได้');

        if (uuid == null || uuid.trim().isEmpty) {
          throw const CryptoFlowException('ไม่สามารถเข้ารหัสได้');
        }

        File encryptedFile;
        try {
          encryptedFile = await Navec.encryptFile(
            filePath: processedFile.path,
            password: password,
            algo: algorithm,
            uuid: uuid,
          );
        } on FormatException catch (error) {
          throw CryptoFlowException(error.message ?? 'ไม่สามารถเข้ารหัสไฟล์ได้');
        } catch (error, stackTrace) {
          debugPrint('❌ Failed to encrypt file: $error');
          debugPrintStack(stackTrace: stackTrace);
          throw const CryptoFlowException('ไม่สามารถเข้ารหัสไฟล์ได้');
        }

        addCleanup(encryptedFile);
        try {
          renamedEncrypted = await IOHelper.renameWithTimestamp(
            encryptedFile,
            prefix: 'file_encrypted',
            extension: '.${Navec.encryptedFileExtension}',
          );
        } on IOHelperException catch (error) {
          throw CryptoFlowException(error.message);
        }
        addCleanup(renamedEncrypted);
        removeCleanup(encryptedFile);

        processedFile = renamedEncrypted;
        didEncrypt = true;
      }

      final type = didEncrypt ? 'encryption' : 'watermark';
      final logId = await _safeApiCall(
        () => MyApi().saveLog(
              email,
              p.basename(processedFile.path),
              uuid,
              signatureCode,
              'create',
              type,
              secret,
              null,
            ),
        'ไม่สามารถบันทึกข้อมูลได้',
      );

      if (logId == null) {
        throw const CryptoFlowException('ไม่สามารถบันทึกข้อมูลได้');
      }

      if (didWatermark && didEncrypt && renamedWatermark != null) {
        removeCleanup(renamedWatermark);
      }

      removeCleanup(processedFile);

      final summary = _buildSummaryMessage(
        didWatermark: didWatermark,
        didEncrypt: didEncrypt,
      );

      return CryptoFlowResult(
        file: processedFile,
        isEncryption: didEncrypt,
        message: summary,
        payload: {
          resultKeys['filePath']: processedFile.path,
          resultKeys['fileEncryptPath']: processedFile.path,
          resultKeys['message']: summary,
          resultKeys['signatureCode']: signatureCode,
          resultKeys['userID']: logId.toString(),
          resultKeys['type']: type,
          resultKeys['uuid']: uuid,
          resultKeys['isEncryption']: didEncrypt,
        },
      );
    } on CryptoFlowException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('❌ CryptoFlow.encrypt unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const CryptoFlowException('ไม่สามารถเข้ารหัสไฟล์ได้');
    } finally {
      await _cleanupPaths(cleanupPaths);
    }
  }

  static Future<CryptoFlowResult> decrypt({
    @required BuildContext context,
    @required String filePath,
    @required String password,
    void Function(String message) onMessage,
  }) async {
    if (filePath == null || filePath.trim().isEmpty) {
      throw const CryptoFlowException('ไม่พบไฟล์');
    }

    final source = File(filePath);
    await validateFile(source, requireEncryptedExtension: true);

    onMessage?.call(messages[CryptoStep.decrypt]);

    final cleanupPaths = <String>{};
    void addCleanup(File file) {
      final path = file?.path;
      if (path != null && path.isNotEmpty) {
        cleanupPaths.add(path);
      }
    }

    void removeCleanup(File file) {
      final path = file?.path;
      if (path != null && path.isNotEmpty) {
        cleanupPaths.remove(path);
      }
    }

    try {
      List decryptData;
      try {
        decryptData = await Navec.decryptFile(
          context: context,
          filePath: filePath,
          password: password,
        );
      } on FormatException catch (error) {
        throw CryptoFlowException(error.message ?? 'ไม่สามารถถอดรหัสไฟล์ได้');
      } catch (error, stackTrace) {
        debugPrint('❌ Failed to decrypt file: $error');
        debugPrintStack(stackTrace: stackTrace);
        throw const CryptoFlowException('ไม่สามารถถอดรหัสไฟล์ได้');
      }

      if (decryptData == null || decryptData.length < 2) {
        throw const CryptoFlowException('ไม่สามารถถอดรหัสไฟล์ได้');
      }

      var outFile = decryptData[0] as File;
      final uuid = decryptData[1] as String;

      if (outFile == null || uuid == null) {
        throw const CryptoFlowException('ไม่สามารถถอดรหัสไฟล์ได้');
      }

      addCleanup(outFile);

      final email = await MyPrefs.getEmail();
      final secret = await MyPrefs.getSecret();

      final isAuthorized = await _safeApiCall(
        () => MyApi().getCheckDecrypt(email, uuid),
        'ไม่สามารถตรวจสอบสิทธิ์ได้',
      );
      if (isAuthorized != true) {
        throw const CryptoFlowUnauthorizedException('คุณไม่มีสิทธิ์ในการเข้าถึงไฟล์นี้!');
      }

      File renamedFile;
      try {
        renamedFile = await IOHelper.renameWithTimestamp(
          outFile,
          prefix: 'file_decrypted',
          extension: p.extension(outFile.path),
        );
      } on IOHelperException catch (error) {
        throw CryptoFlowException(error.message);
      }
      addCleanup(renamedFile);
      removeCleanup(outFile);

      final logId = await _safeApiCall(
        () => MyApi().saveLog(
              email,
              p.basename(filePath),
              uuid,
              null,
              'view',
              'decryption',
              secret,
              null,
            ),
        'ไม่สามารถบันทึกข้อมูลได้',
      );
      if (logId == null) {
        throw const CryptoFlowException('ไม่สามารถบันทึกข้อมูลได้');
      }

      removeCleanup(renamedFile);

      const message = 'ถอดรหัสสำเร็จ';

      return CryptoFlowResult(
        file: renamedFile,
        isEncryption: false,
        message: message,
        payload: {
          resultKeys['filePath']: renamedFile.path,
          resultKeys['fileEncryptPath']: renamedFile.path,
          resultKeys['message']: message,
          resultKeys['userID']: logId.toString(),
          resultKeys['type']: 'decryption',
          resultKeys['uuid']: uuid,
          resultKeys['isEncryption']: false,
        },
      );
    } on CryptoFlowUnauthorizedException {
      rethrow;
    } on CryptoFlowException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('❌ CryptoFlow.decrypt unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const CryptoFlowException('ไม่สามารถถอดรหัสไฟล์ได้');
    } finally {
      await _cleanupPaths(cleanupPaths);
    }
  }

  static String _buildSummaryMessage({
    bool didWatermark,
    bool didEncrypt,
  }) {
    var parts = <String>[];
    if (didWatermark == true) {
      parts.add('ใส่ลายน้ำ');
    }
    if (didEncrypt == true) {
      parts.add('เข้ารหัส');
    }

    if (parts.isEmpty) {
      return 'ดำเนินการสำเร็จ';
    }

    if (parts.length == 1) {
      return '${parts.first}สำเร็จ';
    }

    return '${parts.first}และ${parts.last}สำเร็จ';
  }

  static Future<T> _safeApiCall<T>(
    Future<T> Function() action,
    String errorMessage,
  ) async {
    try {
      return await action();
    } on CryptoFlowException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('❌ CryptoFlow API failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw CryptoFlowException(errorMessage);
    }
  }

  static Future<void> _cleanupPaths(Set<String> paths) async {
    if (paths == null || paths.isEmpty) {
      return;
    }

    for (final path in List<String>.from(paths)) {
      if (path == null || path.trim().isEmpty) {
        continue;
      }
      await IOHelper.tryDelete(File(path));
    }

    paths.clear();
  }
}
