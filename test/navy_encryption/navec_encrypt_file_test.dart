import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/aes.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({@required this.tempPath, @required this.documentsPath})
      : super();

  final String tempPath;
  final String documentsPath;

  @override
  Future<String> getTemporaryPath() async => tempPath;

  @override
  Future<String> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final PathProviderPlatform originalPlatform = PathProviderPlatform.instance;

  group('Navec.encryptFile', () {
    Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('navec_encrypt_test_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        tempPath: tempDirectory.path,
        documentsPath: tempDirectory.path,
      );
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPlatform;
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('returns null when file path is empty', () async {
      final result = await Navec.encryptFile(
        filePath: '',
        password: 'password',
        algo: NotEncrypt(),
        uuid: '00000000-0000-0000-0000-000000000000',
      );

      expect(result, isNull);
    });

    test('returns null when the source file does not exist', () async {
      final missingFilePath = p.join(tempDirectory.path, 'missing.txt');

      final result = await Navec.encryptFile(
        filePath: missingFilePath,
        password: 'password',
        algo: Aes(keyLengthInBytes: 16),
        uuid: '11111111-1111-1111-1111-111111111111',
      );

      expect(result, isNull);
    });

    test('writes encrypted output with NAVEC header and uuid metadata', () async {
      final sourceFile = File(p.join(tempDirectory.path, 'fleet.txt'));
      await sourceFile.writeAsString('Confidential payload for the fleet.');

      const uuid = '12345678-90ab-cdef-1234-567890abcdef';
      final result = await Navec.encryptFile(
        filePath: sourceFile.path,
        password: 'P@ssw0rd',
        algo: Aes(keyLengthInBytes: 16),
        uuid: uuid,
      );

      expect(result, isNotNull);
      final File outputFile = result;
      expect(await outputFile.exists(), isTrue);
      expect(p.extension(outputFile.path), '.${Navec.encryptedFileExtension}');

      final bytes = await outputFile.readAsBytes();
      final minimumHeaderLength = Navec.headerFileSignature.length +
          Navec.headerFileExtensionFieldLength +
          Navec.headerAlgorithmFieldLength +
          Navec.headerUUIDFieldLength;
      expect(bytes.length, greaterThan(minimumHeaderLength));

      final signature =
          utf8.decode(bytes.sublist(0, Navec.headerFileSignature.length));
      expect(signature, Navec.headerFileSignature);

      final extensionFieldStart = Navec.headerFileSignature.length;
      final extensionFieldEnd =
          extensionFieldStart + Navec.headerFileExtensionFieldLength;
      final extensionField = utf8
          .decode(bytes.sublist(extensionFieldStart, extensionFieldEnd))
          .trimRight();
      expect(extensionField, 'txt');

      final algorithmFieldStart = extensionFieldEnd;
      final algorithmFieldEnd =
          algorithmFieldStart + Navec.headerAlgorithmFieldLength;
      final algorithmField = utf8
          .decode(bytes.sublist(algorithmFieldStart, algorithmFieldEnd))
          .trimRight();
      expect(algorithmField, 'AES128');

      final uuidField = utf8
          .decode(bytes.sublist(bytes.length - Navec.headerUUIDFieldLength));
      expect(uuidField, uuid);
    });
  });
}
