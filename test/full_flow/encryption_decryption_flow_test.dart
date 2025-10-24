import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/aes.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../helpers/fake_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final PathProviderPlatform originalPlatform = PathProviderPlatform.instance;

  group('Encryption → Decryption flow', () {
    Directory tempDirectory;
    BuildContext harnessContext;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('navec_flow_test_');
      PathProviderPlatform.instance = FakePathProviderPlatform(
        tempPath: tempDirectory.path,
        documentsPath: tempDirectory.path,
      );
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPlatform;
      if (tempDirectory != null && await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    testWidgets('produces encrypted file and restores original payload with uuid metadata',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                harnessContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(harnessContext, isNotNull);

      const password = 'FleetSecret16';
      const uuid = '8ab6d7b0-1c2d-4e5f-8a9b-123456789abc';
      const originalContent = 'Naval manifest: 4 crates of encryption modules.';

      final sourceFile = File(p.join(tempDirectory.path, 'manifest.txt'));
      await sourceFile.writeAsString(originalContent);

      await tester.runAsync(() async {
        final encryptedFile = await Navec.encryptFile(
          filePath: sourceFile.path,
          password: password,
          algo: Aes(keyLengthInBytes: 16),
          uuid: uuid,
        );

        expect(encryptedFile, isNotNull);
        expect(await encryptedFile.exists(), isTrue);
        expect(p.extension(encryptedFile.path), '.${Navec.encryptedFileExtension}');

        final result = await Navec.decryptFile(
          context: harnessContext,
          filePath: encryptedFile.path,
          password: password,
        );

        expect(result, isNotNull);
        expect(result.length, 2);

        final File decryptedFile = result.first as File;
        final String extractedUuid = result.last as String;

        expect(decryptedFile, isNotNull);
        expect(await decryptedFile.exists(), isTrue);
        expect(await decryptedFile.readAsString(), originalContent);
        expect(extractedUuid, uuid);
      });

      await tester.pump();
    });
  });
}
