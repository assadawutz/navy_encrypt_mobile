library decryption_page;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import 'package:navy_encrypt/etc/utils.dart';
import 'package:navy_encrypt/navy_encryption/navec.dart';
import 'package:navy_encrypt/navy_encryption/watermark.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';

import '../../common/my_dialog.dart';
import '../result/result_page.dart';

part 'decryption_page_view.dart';
part 'decryption_page_view_win.dart';

class DecryptionPage extends StatefulWidget {
  static const routeName = 'decryption';
  final String filePath;

  const DecryptionPage({Key key, this.filePath}) : super(key: key);

  @override
  _DecryptionPageController createState() =>
      _DecryptionPageController(filePath);
}

class _DecryptionPageController extends MyState<DecryptionPage> {
  static const int _maxFileSizeInBytes = 20 * 1024 * 1024;
  String _toBeDecryptedFilePath;
  final _passwordEditingController = TextEditingController();
  var _passwordVisible = false;
  Uint8List _decryptedBytes;
  WatermarkRegisterStatus _registerStatus;

  _DecryptionPageController(this._toBeDecryptedFilePath);

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
    if (filePath != null) _toBeDecryptedFilePath = filePath;

    print('PATH OF FILE TO BE DECRYPTED: $_toBeDecryptedFilePath');

    return isLandscapeLayout(context)
        ? _DecryptionPageViewWin(this)
        : _DecryptionPageView(this);
  }

  _handleClickPasswordEye() {
    setState(() {
      _passwordVisible = !_passwordVisible;
    });
  }

  _updateWatermarkRegisterStatus() async {
    var status = await Watermark.getRegisterStatus();
    setState(() {
      _registerStatus = status;
    });
  }

  _handleClicktoSettingButton() {
    Navigator.pushNamed(
      context,
      SettingsPage.routeName,
    ).then((value) => _updateWatermarkRegisterStatus());
  }

  Future<void> _handleClickGoButton() async {
    final password = _passwordEditingController.text.trim();
    if (password.isEmpty) {
      _showSnackBar('ต้องกรอกรหัสผ่าน');
      return;
    }

    if (_toBeDecryptedFilePath == null ||
        _toBeDecryptedFilePath.trim().isEmpty) {
      _showSnackBar('ไม่พบไฟล์');
      return;
    }

    try {
      await CryptoFlow.validateFile(
        File(_toBeDecryptedFilePath),
        requireEncryptedExtension: true,
      );
    } on CryptoFlowException catch (error) {
      _showSnackBar(error.message);
      return;
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return;
    }

    isLoading = true;
    loadingMessage = CryptoFlow.messages[CryptoStep.decrypt];

    try {
      final result = await CryptoFlow.decrypt(
        context: context,
        filePath: _toBeDecryptedFilePath,
        password: password,
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
    } on CryptoFlowUnauthorizedException catch (error) {
      isLoading = false;
      if (!mounted) {
        return;
      }
      await _showUnauthorizedDialog(error.message);
    } on CryptoFlowException catch (error) {
      isLoading = false;
      _showSnackBar(error.message);
    } catch (error) {
      isLoading = false;
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  Future<void> _showUnauthorizedDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) {
        return MyDialog(
          headerImage: Image.asset(
            'assets/images/ic_unauthorized.png',
            width: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE,
          ),
          body: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 32.0),
                Text(
                  message ?? 'คุณไม่มีสิทธิ์ในการเข้าถึงไฟล์นี้!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 22.0),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(
                        color: Color.fromARGB(255, 31, 150, 205),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
