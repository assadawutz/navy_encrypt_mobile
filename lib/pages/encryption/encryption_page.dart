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
import 'package:navy_encrypt/core/crypto_flow.dart';
import 'package:navy_encrypt/etc/constants.dart';
import 'package:navy_encrypt/navy_encryption/algorithms/base_algorithm.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:navy_encrypt/navy_encryption/watermark.dart';
import 'package:navy_encrypt/pages/result/result_page.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';
import 'package:path/path.dart' as p;

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

    try {
      await CryptoFlow.validateFile(
        File(_toBeEncryptedFilePath),
        forbidEncryptedExtension: _algorithm.code != Navec.notEncryptCode,
      );
    } on CryptoFlowException catch (error) {
      _showSnackBar(error.message);
      return;
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return;
    }

    FocusScope.of(context).unfocus();

    isLoading = true;

    loadingMessage = CryptoFlow.messages[CryptoStep.copy];

    try {
      final result = await CryptoFlow.encrypt(
        context: context,
        filePath: _toBeEncryptedFilePath,
        algorithm: _algorithm,
        password: trimmedPassword,
        watermark: trimmedWatermark,
        onMessage: (message) {
          if (message != null && mounted) {
            loadingMessage = message;
          }
        },
      );

      if (!mounted) {
        return;
      }

      isLoading = false;

      final arguments = Map<String, dynamic>.from(result.payload ?? {})
        ..putIfAbsent(CryptoFlow.resultKeys.filePath, () => result.file?.path)
        ..putIfAbsent(CryptoFlow.resultKeys.fileEncryptPath, () => result.file?.path)
        ..putIfAbsent(CryptoFlow.resultKeys.message, () => result.message)
        ..putIfAbsent(CryptoFlow.resultKeys.isEncryption, () => result.isEncryption);

      Navigator.pushReplacementNamed(
        context,
        ResultPage.routeName,
        arguments: arguments,
      );
    } on CryptoFlowException catch (error) {
      isLoading = false;
      _showSnackBar(error.message);
    } catch (error) {
      isLoading = false;
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
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
