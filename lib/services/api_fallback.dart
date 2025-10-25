import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:navy_encrypt/models/log.dart';
import 'package:navy_encrypt/models/share_log.dart';
import 'package:navy_encrypt/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ApiFallback {
  static const _keyWatermarkProfile = 'fallback.api.watermark.profile';
  static const _keyLogs = 'fallback.api.logs';
  static const _keyShareLogs = 'fallback.api.share_logs';
  static const _keyUsers = 'fallback.api.users';
  static const _keyUuidMap = 'fallback.api.uuid.by.ref_code';
  static const _keySequence = 'fallback.api.sequence';

  static const ApiFallback instance = ApiFallback._();

  const ApiFallback._();

  Future<int> registerWatermark(
    String email,
    String name,
    String phone,
    String refCode,
    String deviceOs,
    String deviceName,
    String deviceId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'email': email,
      'name': name,
      'phone': phone,
      'refCode': refCode,
      'deviceOs': deviceOs,
      'deviceName': deviceName,
      'deviceId': deviceId,
      'activated': false,
    };
    await prefs.setString(_keyWatermarkProfile, json.encode(payload));
    return 1;
  }

  Future<int> activateWatermark(String email, String refCode, String secret) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _readProfile(prefs);
    if (profile == null || profile['email'] != email || profile['refCode'] != refCode) {
      await prefs.setString(
        _keyWatermarkProfile,
        json.encode({
          'email': email,
          'name': '',
          'phone': '',
          'refCode': refCode,
          'deviceOs': '',
          'deviceName': '',
          'deviceId': '',
          'activated': true,
          'secret': secret,
        }),
      );
      return 1;
    }

    profile['activated'] = true;
    profile['secret'] = secret;
    await prefs.setString(_keyWatermarkProfile, json.encode(profile));
    return 1;
  }

  Future<String> getWatermarkSignatureCode(String email, String secret) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _readProfile(prefs) ?? {};
    if (profile['email'] != email) {
      profile['email'] = email;
    }
    profile['secret'] = secret;
    await prefs.setString(_keyWatermarkProfile, json.encode(profile));

    final refCode = profile['refCode'] ?? email ?? '';
    final seed = '$email|$secret|$refCode';
    final digest = sha256.convert(utf8.encode(seed)).bytes;
    final base = base64UrlEncode(digest);
    return base.substring(0, min(24, base.length));
  }

  Future<int> saveLog(
    String email,
    String fileName,
    String uuid,
    String signatureCode,
    String action,
    String type,
    String viewerSecret,
    List<int> shareList,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final nextId = (prefs.getInt(_keySequence) ?? 0) + 1;
    prefs.setInt(_keySequence, nextId);

    final logs = await _readLogs(prefs);
    final entry = {
      'id': nextId,
      'user_name': email ?? 'offline-user',
      'email': email,
      'file_name': fileName,
      'signature_code': signatureCode ?? '',
      'action': action ?? 'create',
      'type': type ?? 'encryption',
      'uuid': uuid,
      'viewer_secret': viewerSecret,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    logs.add(entry);
    await prefs.setString(_keyLogs, json.encode(logs));

    final resolvedShareList = shareList ?? const <int>[];
    if (resolvedShareList.isNotEmpty) {
      await _saveShareLogs(prefs, entry, resolvedShareList);
    }

    return nextId;
  }

  Future<List<User>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString(_keyUsers);
    if (stored == null) {
      final defaults = [
        {
          'id': 1,
          'name': 'เรือเอก (สำรอง) กำพล ขันติพล',
          'email': 'kamphon.reserve@example.mil',
        },
        {
          'id': 2,
          'name': 'พันจ่าโท สมหญิง อารีรักษ์',
          'email': 'somying.aree@example.mil',
        },
        {
          'id': 3,
          'name': 'นาวาตรี ทศพล ชาญชัย',
          'email': 'thotsaphon.chan@example.mil',
        },
      ];
      await prefs.setString(_keyUsers, json.encode(defaults));
      stored = json.encode(defaults);
    }
    return userFromJsonArry(stored);
  }

  Future<String> getUuid(String refCode) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _readUuidMap(prefs);
    final existing = map[refCode];
    if (existing != null && existing is String && existing.isNotEmpty) {
      return existing;
    }
    final generated = const Uuid().v4();
    map[refCode] = generated;
    await prefs.setString(_keyUuidMap, json.encode(map));
    return generated;
  }

  Future<bool> getCheckDecrypt(String email, String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await _readLogs(prefs);
    return logs.any((log) => log['email'] == email && log['uuid'] == uuid);
  }

  Future<List<Log>> getLog(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = await _readLogs(prefs)
        .where((log) => email == null || log['email'] == email)
        .toList();
    return logFromJsonArry(json.encode(logs));
  }

  Future<List<ShareLog>> getShareLog(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final shareLogs = await _readShareLogs(prefs)
        .where((log) => log['log_id'] == id)
        .toList();
    return shareLogFromJsonArry(json.encode(shareLogs));
  }

  Future<Map<String, dynamic>> _readProfile(SharedPreferences prefs) async {
    final payload = prefs.getString(_keyWatermarkProfile);
    if (payload == null) {
      return null;
    }
    return json.decode(payload) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _readLogs(SharedPreferences prefs) async {
    final payload = prefs.getString(_keyLogs);
    if (payload == null) {
      return <Map<String, dynamic>>[];
    }
    final dynamic decoded = json.decode(payload);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _readShareLogs(SharedPreferences prefs) async {
    final payload = prefs.getString(_keyShareLogs);
    if (payload == null) {
      return <Map<String, dynamic>>[];
    }
    final dynamic decoded = json.decode(payload);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _saveShareLogs(
    SharedPreferences prefs,
    Map<String, dynamic> baseLog,
    List<int> shareList,
  ) async {
    final usersRaw = prefs.getString(_keyUsers);
    final users = usersRaw == null
        ? <Map<String, dynamic>>[]
        : (json.decode(usersRaw) as List).cast<Map<String, dynamic>>();
    final logs = await _readShareLogs(prefs);
    for (final target in shareList) {
      final matched = users.firstWhere(
        (user) => user['id'] == target,
        orElse: () => <String, dynamic>{},
      );
      final hasMatch = matched.isNotEmpty;
      logs.add({
        'id': const Uuid().v4().hashCode.abs(),
        'log_id': baseLog['id'],
        'send_name': baseLog['user_name'],
        'send_email': baseLog['email'],
        'receive_name':
            hasMatch ? matched['name'] : 'ไม่ทราบผู้รับ',
        'receive_email':
            hasMatch ? matched['email'] : 'unknown@example.mil',
        'file_name': baseLog['file_name'],
        'signature_code': baseLog['signature_code'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await prefs.setString(_keyShareLogs, json.encode(logs));
  }

  Future<Map<String, dynamic>> _readUuidMap(SharedPreferences prefs) async {
    final payload = prefs.getString(_keyUuidMap);
    if (payload == null) {
      return <String, dynamic>{};
    }
    final decoded = json.decode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }
}
