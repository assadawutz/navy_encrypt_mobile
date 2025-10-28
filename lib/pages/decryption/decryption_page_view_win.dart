part of decryption_page;

class _DecryptionPageViewWin
    extends WidgetView<DecryptionPage, _DecryptionPageController> {
  _DecryptionPageViewWin(_DecryptionPageController state) : super(state);

  @override
  Widget build(BuildContext context) {
    return HeaderScaffold(
      showBackButton: true,
      showProgress: state.isLoading,
      progressMessage: state.loadingMessage,
      body: SingleChildScrollView(
        child: MyContainer(
          //padding: const EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 32.0),
          child: Column(
            //crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncryptDecryptHeader(
                imagePath: 'assets/images/win/ic_encrypt.png',
                title: Constants.decryptionPageTitle,
              ),
              if (state._registerStatus == WatermarkRegisterStatus.initial)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0),
                  child: MyButton(
                    label:
                        'ไปหน้าตั้งค่าเพื่อขอคีย์สำหรับการ\nใช้งานการถอดรหัส',
                    width: 250.0,
                    onClick: state._handleClicktoSettingButton,
                  ),
                ),
              if (state._registerStatus ==
                  WatermarkRegisterStatus.waitForSecret)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0),
                  child: MyButton(
                    label:
                        'ไปหน้าตั้งค่าเพื่อกรอกคีย์ที่ได้รับทางอีเมล\nสำหรับใช้งานการถอดรหัส',
                    width: 300.0,
                    onClick: state._handleClicktoSettingButton,
                  ),
                ),
              if (state._registerStatus == WatermarkRegisterStatus.registered)
                Column(children: [
                  if (state._toBeDecryptedFilePath != null)
                    FileDetails(filePath: state._toBeDecryptedFilePath),
                  const SizedBox(height: 20.0),
                  _buildPasswordField(),
                  const SizedBox(height: 40.0),
                  MyButton(
                    label: 'ดำเนินการ',
                    rightIcon: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: Colors.black,
                        size: 18.0,
                      ),
                    ),
                    width: 180.0,
                    onClick:
                        state.isLoading ? null : state._handleClickGoButton,
                  ),
                  if (state._decryptedBytes != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0),
                      child: Image.memory(state._decryptedBytes),
                    ),
                ])
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return MyFormField(
      label: 'ถอดรหัส',
      hint: 'กรอกรหัสผ่าน',
      //rightIcon: Icon(Icons.keyboard_arrow_down, color: Color(0xFFA7A7A7)),
      controller: state._passwordEditingController,
      enabled: !state.isLoading,
      /*inputFormatters: [
        LengthLimitingTextInputFormatter(16),
      ],*/
      obscureText: !state._passwordVisible,
      rightIcon: Icon(
        state._passwordVisible ? Icons.visibility : Icons.visibility_off,
        color: Color(0xFFA7A7A7),
        size: 20.0,
      ),
      onClickRightIcon: state._handleClickPasswordEye,
    );
  }
}
