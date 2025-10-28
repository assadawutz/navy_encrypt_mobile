import 'dart:io';

import 'package:flutter/material.dart';
import 'package:navy_encrypt/core/io_helper.dart';
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

class CryptoFlow {
  static const int maxFileSizeInBytes = 20 * 1024 * 1024;

  static const Map<CryptoStep, String> messages = {
    CryptoStep.validate: 'กำลังตรวจสอบไฟล์',
    CryptoStep.copy: 'กำลังเตรียมไฟล์',
    CryptoStep.watermark: 'กำลังใส่ลายน้ำ',
    CryptoStep.encrypt: 'กำลังเข้ารหัส',
    CryptoStep.decrypt: 'กำลังถอดรหัส',
  };

  static const Map<String, String> resultKeys = {
    'filePath': 'filePath',
    'fileEncryptPath': 'fileEncryptPath',
    'message': 'message',
    'signatureCode': 'signatureCode',
    'userID': 'userID',
    'type': 'type',
    'uuid': 'uuid',
    'isEncryption': 'isEncryption',
  };

  const CryptoFlow._();

  static Future<void> validateFile(
    File file, {
    bool requireEncryptedExtension = false,
    bool forbidEncryptedExtension = false,
  }) async {
    if (file == null) {
      throw const CryptoFlowException('ไม่พบไฟล์');
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
    var processedFile = await IOHelper.copyToWorkspace(source);

    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();
    final refCode = await MyPrefs.getRefCode();

    String signatureCode;
    String uuid;
    var didWatermark = false;
    var didEncrypt = false;
    final trimmedWatermark = watermark?.trim();

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

      if (watermarkedFile == null) {
        throw const CryptoFlowException('ไม่สามารถใส่ลายน้ำได้');
      }

      processedFile = await IOHelper.renameWithTimestamp(
        watermarkedFile,
        prefix: 'file_watermarked',
        extension: p.extension(watermarkedFile.path),
      );
      didWatermark = true;
    }

    if (algorithm.code != Navec.notEncryptCode) {
      onMessage?.call(messages[CryptoStep.encrypt]);
      uuid = await MyApi().getUuid(refCode);

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
      }

      if (encryptedFile == null) {
        throw const CryptoFlowException('ไม่สามารถเข้ารหัสไฟล์ได้');
      }

      processedFile = await IOHelper.renameWithTimestamp(
        encryptedFile,
        prefix: 'file_encrypted',
        extension: '.${Navec.encryptedFileExtension}',
      );
      didEncrypt = true;
    }

    final type = didEncrypt ? 'encryption' : 'watermark';
    final logId = await MyApi()
        .saveLog(email, p.basename(processedFile.path), uuid, signatureCode, 'create', type, secret, null);

    if (logId == null) {
      throw const CryptoFlowException('ไม่สามารถบันทึกข้อมูลได้');
    }

    final summary = _buildSummaryMessage(didWatermark: didWatermark, didEncrypt: didEncrypt);

    return CryptoFlowResult(
      file: processedFile,
      isEncryption: didEncrypt,
      message: summary,
      payload: {
        resultKeys.filePath: processedFile.path,
        resultKeys.fileEncryptPath: processedFile.path,
        resultKeys.message: summary,
        resultKeys.signatureCode: signatureCode,
        resultKeys.userID: logId.toString(),
        resultKeys.type: type,
        resultKeys.uuid: uuid,
        resultKeys.isEncryption: didEncrypt,
      },
    );
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
    List decryptData;
    try {
      decryptData = await Navec.decryptFile(
        context: context,
        filePath: filePath,
        password: password,
      );
    } on FormatException catch (error) {
      throw CryptoFlowException(error.message ?? 'ไม่สามารถถอดรหัสไฟล์ได้');
    } catch (error) {
      throw CryptoFlowException(error.toString());
    }

    if (decryptData == null || decryptData.length < 2) {
      throw const CryptoFlowException('ไม่สามารถถอดรหัสไฟล์ได้');
    }

    var outFile = decryptData[0] as File;
    final uuid = decryptData[1] as String;

    if (outFile == null || uuid == null) {
      throw const CryptoFlowException('ไม่สามารถถอดรหัสไฟล์ได้');
    }

    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();

    final isAuthorized = await MyApi().getCheckDecrypt(email, uuid);
    if (!isAuthorized) {
      try {
        if (await outFile.exists()) {
          await outFile.delete();
        }
      } catch (_) {}
      throw const CryptoFlowUnauthorizedException('คุณไม่มีสิทธิ์ในการเข้าถึงไฟล์นี้!');
    }

    final renamedFile = await IOHelper.renameWithTimestamp(
      outFile,
      prefix: 'file_decrypted',
      extension: p.extension(outFile.path),
    );

    final logId = await MyApi()
        .saveLog(email, p.basename(filePath), uuid, null, 'view', 'decryption', secret, null);
    if (logId == null) {
      throw const CryptoFlowException('ไม่สามารถบันทึกข้อมูลได้');
    }

    const message = 'ถอดรหัสสำเร็จ';

    return CryptoFlowResult(
      file: renamedFile,
      isEncryption: false,
      message: message,
      payload: {
        resultKeys.filePath: renamedFile.path,
        resultKeys.fileEncryptPath: renamedFile.path,
        resultKeys.message: message,
        resultKeys.userID: logId.toString(),
        resultKeys.type: 'decryption',
        resultKeys.uuid: uuid,
        resultKeys.isEncryption: false,
      },
    );
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
}
