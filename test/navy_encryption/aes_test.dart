import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/aes.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';

void main() {
  group('AES encryption', () {
    test('encrypts and decrypts data symmetrically', () {
      final algorithm = Aes(keyLengthInBytes: 16);
      final password = 'my password';
      final data = utf8.encode('NAVEC protects the fleet');

      final encryptedBytes = algorithm.encrypt(password, Uint8List.fromList(data));
      expect(encryptedBytes, isNotNull);
      expect(encryptedBytes, isNotEmpty);
      expect(encryptedBytes, isNot(equals(Uint8List.fromList(data))));

      final decryptedBytes = algorithm.decrypt(password, encryptedBytes);
      expect(decryptedBytes, isNotNull);
      expect(decryptedBytes, equals(Uint8List.fromList(data)));
    });

    test('returns null when decrypting with the wrong password', () {
      final algorithm = Aes(keyLengthInBytes: 32);
      final password = 'correct horse battery staple';
      final data = utf8.encode('Encrypted payload for NAVEC');

      final encryptedBytes = algorithm.encrypt(password, Uint8List.fromList(data));
      final decryptedBytes = algorithm.decrypt('totally-wrong-password', encryptedBytes);

      expect(decryptedBytes, isNull);
    });
  });

  test('NotEncrypt algorithm intentionally returns null', () {
    final algorithm = NotEncrypt();
    const password = 'irrelevant';
    final data = Uint8List.fromList([1, 2, 3]);

    expect(algorithm.encrypt(password, data), isNull);
    expect(algorithm.decrypt(password, data), isNull);
  });
}
