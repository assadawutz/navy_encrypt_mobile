library encryption_page;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navy_encrypt/common/encrypt_decrypt_header.dart';
import 'package:navy_encrypt/common/file_details.dart';
import 'package:navy_encrypt/common/header_scaffold.dart';
import 'package:navy_encrypt/common/my_button.dart';
import 'package:navy_encrypt/common/my_container.dart';
import 'package:navy_encrypt/common/my_form_field.dart';
import 'package:navy_encrypt/common/my_state.dart';
import 'package:navy_encrypt/common/widget_view.dart';
import 'package:navy_encrypt/etc/constants.dart';
import 'package:navy_encrypt/etc/file_util.dart';
import 'package:navy_encrypt/etc/utils.dart';
import 'package:navy_encrypt/models/loading_message.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:navy_encrypt/navy_encryption/watermark.dart';
import 'package:navy_encrypt/pages/result/result_page.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';
import 'package:navy_encrypt/services/api.dart';
import 'package:navy_encrypt/storage/prefs.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

// import 'package:navy_encrypt/services/api.dart';

part 'encryption_page_view.dart';
part 'encryption_page_view_win.dart';

class EncryptionPage extends StatefulWidget {
  static const routeName = 'encryption';

  final String filePath;

  const EncryptionPage({Key key, this.filePath}) : super(key: key);

  @override
  _EncryptionPageController createState() =>
      _EncryptionPageController(filePath);
}

class _EncryptionPageController extends MyState<EncryptionPage> {
  static const int _maxFileSizeInBytes = 20 * 1024 * 1024;
  String _toBeEncryptedFilePath;
  final _watermarkEditingController = TextEditingController();
  final _passwordEditingController = TextEditingController();
  final _confirmPasswordEditingController = TextEditingController();
  var _passwordVisible = false;
  var _confirmPasswordVisible = false;
  var _algorithm = Navec.algorithms[2];
  WatermarkRegisterStatus _registerStatus;

  _EncryptionPageController(this._toBeEncryptedFilePath);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await _updateWatermarkRegisterStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    var filePath = ModalRoute.of(context).settings.arguments as String;
    if (filePath != null) _toBeEncryptedFilePath = filePath;

    print('PATH OF FILE TO BE ENCRYPTED: $_toBeEncryptedFilePath');

    return isLandscapeLayout(context)
        ? _EncryptionPageViewWin(this)
        : _EncryptionPageView(this);
  }

  _handleClickPasswordEye() {
    setState(() {
      _passwordVisible = !_passwordVisible;
    });
  }

  _handleClickConfirmPasswordEye() {
    setState(() {
      _confirmPasswordVisible = !_confirmPasswordVisible;
    });
  }

  Future<String> _createCopy(String filePath) async {
    final uniqueTempDirPath = (await FileUtil.createUniqueTempDir()).path;
    final newFilePath = '${uniqueTempDirPath}/${p.basename(filePath)}';
    final newFile = await File(filePath).copy(newFilePath);
    return newFile.path;
  }

  Future<void> _handleClickGoButton() async {
    final trimmedWatermark = _watermarkEditingController.text.trim();
    final trimmedPassword = _passwordEditingController.text.trim();
    final trimmedConfirm = _confirmPasswordEditingController.text.trim();

    if (trimmedWatermark.isEmpty && _algorithm.code == Navec.notEncryptCode) {
      _showSnackBar('ต้องกรอกข้อความลายน้ำหรือเลือกวิธีการเข้ารหัส');
      return;
    }

    if (_algorithm.code != Navec.notEncryptCode && trimmedPassword.isEmpty) {
      _showSnackBar('ต้องกรอกรหัสผ่านก่อนเข้ารหัส');
      return;
    }

    if (_algorithm.code != Navec.notEncryptCode &&
        trimmedConfirm != trimmedPassword) {
      _showSnackBar('ยืนยันรหัสผ่านไม่ถูกต้อง');
      return;
    }

    if (_toBeEncryptedFilePath == null ||
        _toBeEncryptedFilePath.trim().isEmpty) {
      _showSnackBar('ไม่พบไฟล์');
      return;
    }

    final originalExtension = p.extension(_toBeEncryptedFilePath).toLowerCase();
    if (_algorithm.code != Navec.notEncryptCode && originalExtension == '.enc') {
      _showSnackBar('ไฟล์นี้ถูกเข้ารหัสแล้ว');
      return;
    }

    try {
      final originalFile = File(_toBeEncryptedFilePath);
      if (!await originalFile.exists()) {
        _showSnackBar('ไม่พบไฟล์');
        return;
      }

      final originalSize = await originalFile.length();
      if (originalSize <= 0) {
        _showSnackBar('ไม่พบไฟล์');
        return;
      }

      if (originalSize > _maxFileSizeInBytes) {
        _showSnackBar('ไฟล์มีขนาดเกิน 20MB');
        return;
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return;
    }

    FocusScope.of(context).unfocus();

    var doWatermark = false;
    var doEncrypt = false;
    String signatureCode;
    String uuid;
    File processedFile;

    isLoading = true;

    try {
      processedFile = File(await _createCopy(_toBeEncryptedFilePath));
    } catch (error) {
      isLoading = false;
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return;
    }

    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();

    Future<File> renameWithPattern(File file, String prefix, String extension) async {
      final directory = p.dirname(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath =
          p.join(directory, '${prefix}_${timestamp}${extension ?? p.extension(file.path)}');
      return file.rename(targetPath);
    }

    try {
      if (trimmedWatermark.isNotEmpty) {
        doWatermark = true;
        loadingMessage = 'กำลังใส่ลายน้ำ';

        try {
          signatureCode = await MyApi().getWatermarkSignatureCode(email, secret);
        } catch (error) {
          _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
          isLoading = false;
          return;
        }

        signatureCode ??= trimmedWatermark;

        final watermarkedFile = await Navec.addWatermark(
          context: context,
          filePath: processedFile.path,
          message: trimmedWatermark,
          email: email ?? '',
          signatureCode: signatureCode,
        );

        if (watermarkedFile == null) {
          _showSnackBar('เกิดข้อผิดพลาด: ไม่สามารถใส่ลายน้ำได้');
          isLoading = false;
          return;
        }

        processedFile = await renameWithPattern(
          watermarkedFile,
          'file_watermarked',
          p.extension(watermarkedFile.path),
        );
      }

      if (_algorithm.code != Navec.notEncryptCode) {
        doEncrypt = true;
        final refCode = await MyPrefs.getRefCode();
        uuid = await MyApi().getUuid(refCode);

        if (uuid == null || uuid.trim().isEmpty) {
          _showSnackBar('ไม่สามารถเข้ารหัสได้');
          isLoading = false;
          return;
        }

        Provider.of<LoadingMessage>(context, listen: false)
            .setMessage('กำลังเข้ารหัส');

        final encryptedFile = await Navec.encryptFile(
          filePath: processedFile.path,
          password: trimmedPassword,
          algo: _algorithm,
          uuid: uuid,
        );

        if (encryptedFile == null) {
          _showSnackBar('เกิดข้อผิดพลาด: ไม่สามารถเข้ารหัสไฟล์ได้');
          isLoading = false;
          return;
        }

        processedFile = await renameWithPattern(
          encryptedFile,
          'file_encrypted',
          '.${Navec.encryptedFileExtension}',
        );
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      isLoading = false;
      return;
    }

    String getLog;
    try {
      if (processedFile != null) {
        final fileName = p.basename(processedFile.path);
        final type = doEncrypt ? 'encryption' : 'watermark';
        final logId = await MyApi()
            .saveLog(email, fileName, uuid, signatureCode, 'create', type, secret, null);
        if (logId == null) {
          _showSnackBar('ไม่สามารถบันทึกข้อมูลได้');
          isLoading = false;
          return;
        }
        getLog = logId.toString();
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      isLoading = false;
      return;
    }

    isLoading = false;

    var message = doWatermark ? 'ใส่ลายน้ำ' : '';
    if (doEncrypt) {
      message = '${message.isEmpty ? '' : '$messageและ'}เข้ารหัส';
    }
    message = '$messageสำเร็จ';

    if (!mounted) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      ResultPage.routeName,
      arguments: {
        'filePath': processedFile.path,
        'message': message,
        'userID': getLog,
        'isEncryption': doEncrypt,
        'fileEncryptPath': processedFile.path,
        'signatureCode': signatureCode,
        'type': doEncrypt ? 'encryption' : 'watermark'
      },
    );
  }

  _handleChangeAlgorithm(BaseAlgorithm algo) {
    setState(() {
      _algorithm = algo;
      _passwordEditingController.clear();
      _confirmPasswordEditingController.clear();
    });
  }

  _updateWatermarkRegisterStatus() async {
    var status = await Watermark.getRegisterStatus();
    setState(() {
      _registerStatus = status;
    });
  }

  Future<bool> _hasRegisteredWatermark() async {
    return await Watermark.getRegisterStatus() ==
        WatermarkRegisterStatus.registered;
  }

  _handleClicktoSettingButton() {
    Navigator.pushNamed(
      context,
      SettingsPage.routeName,
    ).then((value) => _updateWatermarkRegisterStatus());
    ;
  }

  bool _canWatermarkThisFileType() {
    /*var extension =
        p.extension(_toBeEncryptedFilePath).substring(1).toLowerCase();*/

    return Constants.imageFileTypeList
            .where((fileType) => fileType.fileExtension == _fileExtension)
            .isNotEmpty ||
        Constants.documentFileTypeList
            .where((fileType) => fileType.fileExtension == _fileExtension)
            .isNotEmpty;
  }

  /*Future<bool> _isWatermarkEnabled() async {
    return await _hasRegisteredWatermark() && _canWatermarkThisFileType();
  }*/

  _handleResume() {
    setState(() {}); // Update watermark status when resume from settings page
  }

  String get _fileExtension =>
      p.extension(_toBeEncryptedFilePath).substring(1).toLowerCase();

  void _showSnackBar(String message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
