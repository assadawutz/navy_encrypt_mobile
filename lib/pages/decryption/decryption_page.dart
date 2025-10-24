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
import 'package:navy_encrypt/etc/constants.dart';
import 'package:navy_encrypt/etc/utils.dart';
import 'package:navy_encrypt/core/crypto_flow.dart';
import 'package:navy_encrypt/navy_encryption/watermark.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';
import 'package:navy_encrypt/storage/prefs.dart';
import 'package:path/path.dart' as p;

import '../../common/my_dialog.dart';
import '../../services/api.dart';
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
  static const int _maxFileSizeInBytes = CryptoFlow.maxFileSizeInBytes;
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

    File sourceFile;
    try {
      sourceFile = File(_toBeDecryptedFilePath);
      if (!await sourceFile.exists()) {
        _showSnackBar('ไม่พบไฟล์');
        return;
      }

      if (!sourceFile.path.toLowerCase().endsWith('.enc')) {
        _showSnackBar('ไฟล์ต้องมีนามสกุล .enc');
        return;
      }

      final size = await sourceFile.length();
      if (size <= 0) {
        _showSnackBar('ไม่พบไฟล์');
        return;
      }

      if (size > _maxFileSizeInBytes) {
        _showSnackBar('ไฟล์มีขนาดเกิน 20MB');
        return;
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      return;
    }

    isLoading = true;
    CryptoFlowResult flowResult;
    File outFile;
    String uuid;
    final email = await MyPrefs.getEmail();
    final secret = await MyPrefs.getSecret();

    try {
      flowResult = await CryptoFlow.decrypt(
        context: context,
        filePath: _toBeDecryptedFilePath,
        password: password,
      );
      outFile = flowResult.file;
      uuid = flowResult.uuid;
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      isLoading = false;
      return;
    }

    if (outFile == null || uuid == null) {
      isLoading = false;
      _showSnackBar('เกิดข้อผิดพลาด: ไม่สามารถถอดรหัสไฟล์ได้');
      return;
    }

    try {
      final statusCheckDecrypt = await MyApi().getCheckDecrypt(email, uuid);
      if (!statusCheckDecrypt) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(builder: (context, setState) {
                return MyDialog(
                  headerImage: Image.asset(
                      'assets/images/ic_unauthorized.png',
                      width: Constants.LIST_DIALOG_HEADER_IMAGE_SIZE),
                  body: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 32.0),
                        Text(
                          'คุณไม่มีสิทธิ์ในการเข้าถึงไฟล์นี้!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 22.0),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          overflowAlignment: OverflowBarAlignment.end,
                          overflowDirection: VerticalDirection.down,
                          overflowSpacing: 0,
                          children: <Widget>[
                            TextButton(
                              child: Text(
                                "ตกลง",
                                style: TextStyle(
                                  color: Color.fromARGB(255, 31, 150, 205),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context, false);
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              });
            },
          );
        }

        isLoading = false;
        return;
      }
    } catch (error) {
      isLoading = false;
      showOkDialog(context, 'เกิดข้อผิดพลาดในการตรวจสอบสิทธิ์!');
      return;
    }

    final decryptedExtension = p.extension(outFile.path);
    final targetPath = p.join(
      p.dirname(outFile.path),
      'file_decrypted_${DateTime.now().millisecondsSinceEpoch}${decryptedExtension}',
    );

    try {
      outFile = await outFile.rename(targetPath);
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      isLoading = false;
      return;
    }

    String getLog;
    try {
      final fileName = p.basename(_toBeDecryptedFilePath);
      final logId = await MyApi()
          .saveLog(email, fileName, uuid, null, 'view', "decryption", secret, null);
      if (logId == null) {
        _showSnackBar('ไม่สามารถบันทึกข้อมูลได้');
        isLoading = false;
        return;
      }
      getLog = logId.toString();
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
      isLoading = false;
      return;
    }

    isLoading = false;

    if (!mounted) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      ResultPage.routeName,
      arguments: {
        'filePath': outFile.path,
        'message': 'ถอดรหัสสำเร็จ',
        'isEncryption': false,
        'userID': getLog,
        'fileEncryptPath': outFile.path,
        'signatureCode': null,
        'type': 'decryption'
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
