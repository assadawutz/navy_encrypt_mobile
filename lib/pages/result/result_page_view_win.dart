part of result_page;

class _ResultPageViewWin extends WidgetView<ResultPage, _ResultPageController> {
  _ResultPageViewWin(_ResultPageController state) : super(state);

  @override
  Widget build(BuildContext context) {
    final actions = buildResultActions(state);
    final isExtraWide = screenWidth(context) >= 1100.0;

    return HeaderScaffold(
      showBackButton: true,
      showProgress: state.isLoading,
      header: EncryptDecryptHeader(
        imagePath: 'assets/images/win/ic_encrypt.png',
        title: state._isEncFile
            ? Constants.encryptionPageTitle
            : Constants.decryptionPageTitle,
      ),
      body: SingleChildScrollView(
        child: MyContainer(
          padding: const EdgeInsets.fromLTRB(48.0, 32.0, 48.0, 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Image.asset(
                  'assets/images/ic_success.png',
                  width: 90.0,
                ),
              ),
              Text(
                state._message,
                style: const TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12.0),
              if (state._filePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: FileDetails(filePath: state._filePath),
                ),
              const SizedBox(height: 32.0),
              _ResultActionButtonList(
                actions: actions,
                useWrapLayout: true,
                buttonWidth: isExtraWide ? 220.0 : 200.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
