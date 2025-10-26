import 'dart:io';

import 'package:navy_encrypt/core/crypto_flow.dart';

class ResultFileResolution {
  final File file;
  final String errorMessage;

  const ResultFileResolution({this.file, this.errorMessage});
}

class ResultFileResolver {
  const ResultFileResolver._();

  static Future<ResultFileResolution> resolve(List<String> candidates) async {
    if (candidates == null || candidates.isEmpty) {
      return const ResultFileResolution(errorMessage: 'ไม่พบไฟล์');
    }

    String fallbackMessage = 'ไม่พบไฟล์';

    for (final rawPath in candidates) {
      final path = rawPath?.trim();
      if (path == null || path.isEmpty) {
        continue;
      }

      try {
        final file = File(path);
        await CryptoFlow.validateFile(file);
        return ResultFileResolution(file: file);
      } on CryptoFlowException catch (error) {
        fallbackMessage = error.message ?? fallbackMessage;
      } catch (error) {
        fallbackMessage = 'เกิดข้อผิดพลาด: ${error.toString()}';
      }
    }

    return ResultFileResolution(errorMessage: fallbackMessage);
  }
}
