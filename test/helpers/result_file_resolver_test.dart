import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:navy_encrypt/core/result_file_resolver.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ResultFileResolver', () {
    Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('result_resolver_');
    });

    tearDown(() async {
      if (tempDirectory != null && await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('returns first valid file when earlier candidates fail', () async {
      final validFile = File(p.join(tempDirectory.path, 'valid.txt'));
      await validFile.writeAsString('navy');

      final resolution = await ResultFileResolver.resolve([
        p.join(tempDirectory.path, 'missing.enc'),
        validFile.path,
      ]);

      expect(resolution.file, isNotNull);
      expect(resolution.file.path, validFile.path);
      expect(resolution.errorMessage, isNull);
    });

    test('provides fallback message when no candidate is usable', () async {
      final resolution = await ResultFileResolver.resolve([
        p.join(tempDirectory.path, 'missing.enc'),
      ]);

      expect(resolution.file, isNull);
      expect(resolution.errorMessage, isNotEmpty);
    });
  });
}
