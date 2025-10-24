import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MyPrefs {
  static const KEY_REF_CODE = 'ref_code';
  static const KEY_EMAIL = 'email';
  static const KEY_SECRET = 'secret';
  static const KEY_WATERMARK_REGISTER_STATUS = 'watermark_register_status';
  static const KEY_OAUTH_CREDENTIALS = 'oauth_credentials';
  static const KEY_DEVICE_ID = 'device_id';

  static const _secureKeyPrefix = 'secure.navy_encrypt.';
  static const _fallbackKeyPrefix = 'encrypted.navy_encrypt.';
  static const _fallbackSalt = 'navy_encrypt_fallback_salt_v1';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<SharedPreferences> _getSharedPref() async {
    return SharedPreferences.getInstance();
  }

  static String _buildSecureKey(String key) => '$_secureKeyPrefix$key';

  static String _buildFallbackKey(String key) => '$_fallbackKeyPrefix$key';

  static Future<void> _removeLegacyPlainValue(String key) async {
    final prefs = await _getSharedPref();
    await prefs.remove(key);
  }

  static Future<void> _writeSecureValue(String key, String value) async {
    if (value == null) {
      await _deleteSecureValue(key);
      return;
    }

    var storedSecurely = false;
    try {
      await _secureStorage.write(key: _buildSecureKey(key), value: value);
      storedSecurely = true;
    } catch (_) {
      storedSecurely = false;
    }

    if (storedSecurely) {
      await _deleteFallbackValue(key);
    } else {
      await _writeFallbackValue(key, value);
    }

    await _removeLegacyPlainValue(key);
  }

  static Future<void> _deleteSecureValue(String key) async {
    try {
      await _secureStorage.delete(key: _buildSecureKey(key));
    } catch (_) {}
    await _deleteFallbackValue(key);
    await _removeLegacyPlainValue(key);
  }

  static Future<String> _readSecureValue(String key) async {
    try {
      final secureValue = await _secureStorage.read(key: _buildSecureKey(key));
      if (secureValue != null) {
        return secureValue;
      }
    } catch (_) {}

    final fallbackValue = await _readFallbackValue(key);
    if (fallbackValue != null) {
      return fallbackValue;
    }

    final prefs = await _getSharedPref();
    final legacy = prefs.getString(key);
    if (legacy != null) {
      await _writeSecureValue(key, legacy);
      return legacy;
    }

    return null;
  }

  static Future<void> _writeFallbackValue(String key, String value) async {
    if (value == null) {
      await _deleteFallbackValue(key);
      return;
    }
    final prefs = await _getSharedPref();
    final encrypted = await _encryptForFallback(value);
    await prefs.setString(_buildFallbackKey(key), encrypted);
  }

  static Future<String> _readFallbackValue(String key) async {
    final prefs = await _getSharedPref();
    final payload = prefs.getString(_buildFallbackKey(key));
    if (payload == null) {
      return null;
    }
    final decrypted = await _decryptForFallback(payload);
    if (decrypted == null) {
      await prefs.remove(_buildFallbackKey(key));
    }
    return decrypted;
  }

  static Future<void> _deleteFallbackValue(String key) async {
    final prefs = await _getSharedPref();
    await prefs.remove(_buildFallbackKey(key));
  }

  static Future<String> _encryptForFallback(String value) async {
    final encrypter = await _fallbackEncrypter();
    final iv = await _fallbackInitializationVector();
    return encrypter.encrypt(value, iv: iv).base64;
  }

  static Future<String> _decryptForFallback(String payload) async {
    try {
      final encrypter = await _fallbackEncrypter();
      final iv = await _fallbackInitializationVector();
      return encrypter.decrypt64(payload, iv: iv);
    } catch (_) {
      return null;
    }
  }

  static Future<encrypt.Encrypter> _fallbackEncrypter() async {
    final keyBytes = await _fallbackKeyBytes();
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    return encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
  }

  static Future<Uint8List> _fallbackKeyBytes() async {
    final deviceId = await _getRawDeviceIdentity();
    final hash = sha256.convert(utf8.encode('$deviceId|$_fallbackSalt')).bytes;
    return Uint8List.fromList(hash.sublist(0, 32));
  }

  static Future<encrypt.IV> _fallbackInitializationVector() async {
    final deviceId = await _getRawDeviceIdentity();
    final hash = sha256.convert(utf8.encode('$_fallbackSalt|$deviceId')).bytes;
    return encrypt.IV(Uint8List.fromList(hash.sublist(0, 16)));
  }

  static Future<String> _getRawDeviceIdentity() async {
    try {
      final secureValue =
          await _secureStorage.read(key: _buildSecureKey(KEY_DEVICE_ID));
      if (secureValue != null && secureValue.isNotEmpty) {
        final prefs = await _getSharedPref();
        await prefs.remove(KEY_DEVICE_ID);
        return secureValue;
      }
    } catch (_) {}

    final prefs = await _getSharedPref();
    var stored = prefs.getString(KEY_DEVICE_ID);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final generated = const Uuid().v4();
    try {
      await _secureStorage.write(
        key: _buildSecureKey(KEY_DEVICE_ID),
        value: generated,
      );
      await prefs.remove(KEY_DEVICE_ID);
    } catch (_) {
      await prefs.setString(KEY_DEVICE_ID, generated);
    }
    return generated;
  }

  static Future<String> getRefCode() async {
    return (await _getSharedPref()).getString(KEY_REF_CODE);
  }

  static Future<void> setRefCode(String refCode) async {
    var sharedPref = await _getSharedPref();
    if (refCode == null) {
      await sharedPref.remove(KEY_REF_CODE);
    } else {
      await sharedPref.setString(KEY_REF_CODE, refCode);
    }
  }

  static Future<String> getEmail() async {
    return (await _getSharedPref()).getString(KEY_EMAIL);
  }

  static Future<void> setEmail(String email) async {
    var sharedPref = await _getSharedPref();
    if (email == null) {
      await sharedPref.remove(KEY_EMAIL);
    } else {
      await sharedPref.setString(KEY_EMAIL, email);
    }
  }

  static Future<String> getSecret() async {
    return _readSecureValue(KEY_SECRET);
  }

  static Future<void> setSecret(String secret) async {
    await _writeSecureValue(KEY_SECRET, secret);
  }

  static Future<String> getOAuthCredentials(String serviceName) async {
    final key = '${serviceName}_${KEY_OAUTH_CREDENTIALS}';
    return _readSecureValue(key);
  }

  static Future<void> setOAuthCredentials(
      String serviceName, String credentials) async {
    final key = '${serviceName}_${KEY_OAUTH_CREDENTIALS}';
    await _writeSecureValue(key, credentials);
  }

  static Future<String> getOrCreateDeviceId() async {
    return _getRawDeviceIdentity();
  }
}
