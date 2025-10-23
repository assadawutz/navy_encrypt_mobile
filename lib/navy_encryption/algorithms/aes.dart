import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';

class Aes extends BaseAlgorithm {
  final iv = enc.IV.fromLength(16);

  Aes({int keyLengthInBytes})
      : super(
            code: 'AES${keyLengthInBytes * 8}',
            text: 'AES ${keyLengthInBytes * 8}',
            keyLengthInBytes: keyLengthInBytes);

  @override
  Uint8List encrypt(String password, Uint8List bytes) {
    var encrypted = _createEncrypter(password).encryptBytes(bytes, iv: iv);
    return encrypted.bytes;
  }

  @override
  Uint8List decrypt(String password, Uint8List bytes) {
    var decrypted;
    try {
      decrypted =
          _createEncrypter(password).decryptBytes(enc.Encrypted(bytes), iv: iv);
    } catch (e) {
      print(e);
    } finally {}
    return decrypted == null ? null : Uint8List.fromList(decrypted);
  }

  enc.Encrypter _createEncrypter(String password) {
    if (keyLengthInBytes == null || keyLengthInBytes <= 0) {
      throw StateError('Invalid AES key length: $keyLengthInBytes');
    }

    final trimmedPassword = (password ?? '').trim();
    final padByte = Navec.passwordPadChar.codeUnitAt(0);
    final passwordBytes = utf8.encode(trimmedPassword);

    List<int> keyBytes;
    if (passwordBytes.length >= keyLengthInBytes) {
      keyBytes = passwordBytes.sublist(0, keyLengthInBytes);
    } else {
      keyBytes = List<int>.from(passwordBytes)
        ..addAll(List<int>.filled(keyLengthInBytes - passwordBytes.length, padByte));
    }

    final key = enc.Key(Uint8List.fromList(keyBytes));
    return enc.Encrypter(enc.AES(key));
  }
}
