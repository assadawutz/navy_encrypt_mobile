part of settings_page;

class _SettingsPageViewWin
    extends WidgetView<SettingsPage, _SettingsPageController> {
  _SettingsPageViewWin(_SettingsPageController state) : super(state);

  @override
  Widget build(BuildContext context) {
    return HeaderScaffold(
      showBackButton: true,
      showSettingsButton: false,
      showProgress: state.isLoading,
      header: EncryptDecryptHeader(
        imagePath: 'assets/images/ic_setting.png',
        title: Constants.watermarkSettingsPageTitle,
      ),
      body: SingleChildScrollView(
        child: MyContainer(
          padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 40.0),
          child: _SettingsContent(
            state: state,
            isDesktopLayout: true,
          ),
        ),
      ),
    );
  }
}
