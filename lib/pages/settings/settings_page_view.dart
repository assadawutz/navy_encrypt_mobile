part of settings_page;

class _SettingsPageView
    extends WidgetView<SettingsPage, _SettingsPageController> {
  _SettingsPageView(_SettingsPageController state) : super(state);

  @override
  Widget build(BuildContext context) {
    return HeaderScaffold(
      showBackButton: true,
      showSettingsButton: false,
      showProgress: state.isLoading,
      header: EncryptDecryptHeader(
        imagePath: 'assets/images/ic_setting_white.png',
        title: Constants.watermarkSettingsPageTitle,
      ),
      body: SingleChildScrollView(
        child: MyContainer(
          padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
          child: _SettingsContent(
            state: state,
            isDesktopLayout: false,
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  final _SettingsPageController state;
  final bool isDesktopLayout;

  const _SettingsContent({
    Key key,
    @required this.state,
    this.isDesktopLayout = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = state._registerStatus;

    return Column(
      children: [
        if (isDesktopLayout)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: EncryptDecryptHeader(
              imagePath: 'assets/images/ic_setting.png',
              title: Constants.watermarkSettingsPageTitle,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            'assets/images/${status == WatermarkRegisterStatus.registered ? "ic_success.png" : "ic_key.png"}',
            width: isDesktopLayout ? 60.0 : 120.0,
          ),
        ),
        if (status == null) const CircularProgressIndicator(),
        if (status == WatermarkRegisterStatus.registered)
          FutureBuilder(
            future: MyPrefs.getEmail(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              final email = snapshot.hasData ? snapshot.data : '';

              return Column(
                children: [
                  Text(
                    'เปิดใช้งานระบบลายน้ำบนอุปกรณ์นี้แล้ว\n(อีเมล $email)',
                    style: const TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktopLayout ? 12.0 : 24.0),
                  Container(
                    margin: EdgeInsets.all(isDesktopLayout ? 16.0 : 0.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(width: 1.0, color: Colors.green),
                    ),
                    child: Text(
                      'เลขรหัสลายเซ็นดิจิตอล (Digital Signature) ของอีเมล $email จะถูกบันทึกลงในลายน้ำ ทุกครั้งที่มีการใส่ลายน้ำลงในรูปภาพ/เอกสารบนอุปกรณ์นี้',
                      style: const TextStyle(
                        fontSize: 20.0,
                        color: Color(0xFF319700),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: isDesktopLayout ? 24.0 : 48.0),
                  MyButton(
                    label: 'ขอคีย์ใหม่',
                    width: isDesktopLayout ? 250.0 : 230.0,
                    backgroundColor: Colors.deepOrange,
                    onClick: state._handleClickLogoutButton,
                  ),
                ],
              );
            },
          ),
        if (status == WatermarkRegisterStatus.initial)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: MyButton(
              label: 'ขอคีย์ สำหรับการใช้งานระบบลายน้ำ',
              width: 260.0,
              onClick: state._handleClickRequestKeyButton,
            ),
          ),
        if (status == WatermarkRegisterStatus.waitForSecret)
          Column(
            children: [
              FutureBuilder(
                future: MyPrefs.getEmail(),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  final email = snapshot.hasData ? snapshot.data : '';

                  return MyFormField(
                    subLabel:
                        'กรอกคีย์ที่ได้รับทางอีเมล $email เพื่อเปิดใช้งานระบบลายน้ำบนอุปกรณ์นี้',
                    hint: 'คีย์ (Private Key)',
                    multiline: false,
                    controller: state._privateKeyEditingController,
                  );
                },
              ),
              SizedBox(height: isDesktopLayout ? 32.0 : 24.0),
              if (!isDesktopLayout)
                Column(
                  children: [
                    MyButton(
                      label: 'ตกลง',
                      width: 150.0,
                      onClick: state._handleClickSaveButton,
                    ),
                    const SizedBox(height: 12.0),
                    MyButton(
                      label: 'ยกเลิก',
                      width: 150.0,
                      isOutlinedButton: true,
                      onClick: state._handleClickCancelButton,
                    ),
                  ],
                ),
              if (isDesktopLayout)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MyButton(
                      label: 'ตกลง',
                      width: 160.0,
                      onClick: state._handleClickSaveButton,
                    ),
                    const SizedBox(width: 24.0),
                    MyButton(
                      label: 'ยกเลิก',
                      width: 160.0,
                      isOutlinedButton: true,
                      onClick: state._handleClickCancelButton,
                    ),
                  ],
                ),
            ],
          ),
        SizedBox(height: isDesktopLayout ? 24.0 : 32.0),
        InkWell(
          onTap: state._handleLaunchManual,
          child: const Text(
            'คู่มือการใช้งาน',
            style: TextStyle(
              fontSize: 22.0,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
