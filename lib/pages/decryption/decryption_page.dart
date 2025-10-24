library decryption_page;

import 'dart:io';
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
  String _toBeDecryptedFilePath;
  final _passwordEditingController = TextEditingController();
  var _passwordVisible = false;
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

    isLoading = true;
    loadingMessage = 'กำลังถอดรหัส';

    try {
      final result = await CryptoFlow.runDecryption(
        context: context,
        sourcePath: _toBeDecryptedFilePath,
        password: password,
      );

      isLoading = false;

      if (result.unauthorized) {
        if (mounted) {
          _showUnauthorizedDialog();
        }
        return;
      }

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        ResultPage.routeName,
        arguments: result.resultArguments,
      );
    } on CryptoFlowException catch (error) {
      isLoading = false;
      _showSnackBar(error.message);
    } catch (error) {
      isLoading = false;
      _showSnackBar('เกิดข้อผิดพลาด: ${error.toString()}');
    }
  }

  void _showUnauthorizedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return MyDialog(
            headerImage: Image.asset('assets/images/ic_unauthorized.png',
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

  void _showSnackBar(String message) {
    if (!mounted || message == null || message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
