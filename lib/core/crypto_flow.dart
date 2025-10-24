import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../etc/file_util.dart';
import '../navy_encryption/algorithms/base_algorithm.dart';
import '../navy_encryption/navec.dart';

class CryptoFlowResult {
  final File file;
  final bool encrypted;
  final bool watermarked;
  final String uuid;
  final String signatureCode;

  const CryptoFlowResult({
    @required this.file,
    @required this.encrypted,
    @required this.watermarked,
    this.uuid,
    this.signatureCode,
  });

  Map<String, dynamic> toArguments({
    @required String message,
    @required String userId,
    @required String type,
  }) {
    return {
      'filePath': file.path,
      'message': message,
      'userID': userId,
      'isEncryption': encrypted,
      'fileEncryptPath': file.path,
      'signatureCode': signatureCode,
      'type': type,
    };
  }
}

class CryptoFlow {
  static const int maxFileSizeInBytes = 20 * 1024 * 1024;

  static Future<File> _validateSource(String sourcePath) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) {
      throw ArgumentError('Source path is empty.');
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('File not found', sourcePath);
    }

    final size = await source.length();
    if (size <= 0) {
      throw FileSystemException('File is empty', sourcePath);
    }

    if (size > maxFileSizeInBytes) {
      throw FileSystemException(
        'File exceeds ${maxFileSizeInBytes ~/ (1024 * 1024)}MB limit',
        sourcePath,
      );
    }

    return source;
  }

  static Future<File> _createWorkspaceCopy(String path) async {
    final validated = await _validateSource(path);
    final tempDir = await FileUtil.createUniqueTempDir();
    final target = File(p.join(tempDir.path, p.basename(validated.path)));
    return validated.copy(target.path);
  }

  static Future<File> watermark({
    @required BuildContext context,
    @required File file,
    @required String message,
    String email,
    String signatureCode,
  }) async {
    final output = await Navec.addWatermark(
      context: context,
      filePath: file.path,
      message: message,
      email: email ?? '',
      signatureCode: signatureCode ?? message,
    );

    if (output == null) {
      throw StateError('Unable to apply watermark.');
    }

    return output;
  }

  static Future<File> encrypt({
    @required File file,
    @required BaseAlgorithm algorithm,
    @required String password,
    String uuid,
  }) async {
    if (algorithm == null || algorithm.code == Navec.notEncryptCode) {
      return file;
    }

    if (password == null || password.isEmpty) {
      throw ArgumentError('Password is required for encryption.');
    }

    final encrypted = await Navec.encryptFile(
      filePath: file.path,
      password: password,
      algo: algorithm,
      uuid: uuid ?? '',
    );

    if (encrypted == null) {
      throw StateError('Encryption returned null file.');
    }

    return encrypted;
  }

  static Future<CryptoFlowResult> processEncryption({
    @required BuildContext context,
    @required String sourcePath,
    @required BaseAlgorithm algorithm,
    @required String password,
    String watermarkMessage,
    String email,
    String signatureCode,
    String uuid,
  }) async {
    final workspace = await _createWorkspaceCopy(sourcePath);
    var workingFile = workspace;
    var watermarked = false;

    if (watermarkMessage != null && watermarkMessage.trim().isNotEmpty) {
      workingFile = await watermark(
        context: context,
        file: workingFile,
        message: watermarkMessage,
        email: email,
        signatureCode: signatureCode,
      );
      watermarked = true;
    }

    final encryptedFile = await encrypt(
      file: workingFile,
      algorithm: algorithm,
      password: password,
      uuid: uuid,
    );

    final encrypted = algorithm != null && algorithm.code != Navec.notEncryptCode;

    return CryptoFlowResult(
      file: encryptedFile,
      encrypted: encrypted,
      watermarked: watermarked,
      uuid: uuid,
      signatureCode: signatureCode,
    );
  }

  static Future<CryptoFlowResult> decrypt({
    @required BuildContext context,
    @required String filePath,
    @required String password,
  }) async {
    await _validateSource(filePath);

    final result = await Navec.decryptFile(
      context: context,
      filePath: filePath,
      password: password,
    );

    final outFile = result[0] as File;
    final uuid = result[1] as String;
    if (outFile == null) {
      throw StateError('Unable to decrypt file.');
    }

    return CryptoFlowResult(
      file: outFile,
      encrypted: false,
      watermarked: false,
      uuid: uuid,
    );
  }
}
