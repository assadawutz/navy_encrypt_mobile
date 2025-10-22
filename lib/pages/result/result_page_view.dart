part of result_page;

class _ResultPageView extends WidgetView<ResultPage, _ResultPageController> {
  _ResultPageView(_ResultPageController state) : super(state);

  @override
  Widget build(BuildContext context) {
    final actions = buildResultActions(state);
    final isWideLayout = screenWidth(context) >= 480.0;

    return HeaderScaffold(
        showBackButton: true,
        showProgress: state.isLoading,
        header: EncryptDecryptHeader(
          imagePath: 'assets/images/ic_encrypt.png',
          title: state._isEncFile
              ? Constants.encryptionPageTitle
              : Constants.decryptionPageTitle,
        ),
        body: SingleChildScrollView(
          child: MyContainer(
            //padding: const EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 32.0),
            child: Column(
              children: [
                if (false /*Platform.isWindows*/)
                  EncryptDecryptHeader(
                    imagePath: 'assets/images/win/ic_encrypt_grey.png',
                    title: state._isEncFile
                        ? Constants.encryptionPageTitle
                        : Constants.decryptionPageTitle,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset('assets/images/ic_success.png',
                      width: !Platform.isWindows ? 120.0 : 60.0),
                ),
                Text(
                  state._message,
                  style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: !Platform.isWindows ? 16.0 : 8.0),
                if (state._filePath != null)
                  FileDetails(filePath: state._filePath),
                SizedBox(height: !Platform.isWindows ? 32.0 : 16.0),
                _ResultActionButtonList(
                  actions: actions,
                  useWrapLayout: isWideLayout,
                  buttonWidth: 200.0,
                ),
              ],
            ),
          ),
        ));
  }
}

class _ResultActionButtonList extends StatelessWidget {
  final List<_ResultActionData> actions;
  final bool useWrapLayout;
  final double buttonWidth;

  const _ResultActionButtonList({
    Key key,
    @required this.actions,
    this.useWrapLayout = false,
    this.buttonWidth = 220.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (actions == null || actions.isEmpty) {
      return SizedBox.shrink();
    }

    final buttons = actions
        .map(
          (action) => SizedBox(
            width: buttonWidth,
            child: _ResultActionButton(action: action),
          ),
        )
        .toList();

    if (useWrapLayout) {
      return Align(
        alignment: Alignment.center,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 24.0,
          runSpacing: 16.0,
          children: buttons,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < buttons.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == buttons.length - 1 ? 0.0 : 16.0),
            child: Align(
              alignment: Alignment.center,
              child: buttons[i],
            ),
          ),
      ],
    );
  }
}

class _ResultActionButton extends StatelessWidget {
  final _ResultActionData action;

  const _ResultActionButton({Key key, @required this.action}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MyButton(
      label: action.label,
      rightIcon: action.icon,
      width: double.infinity,
      onClick: action.onPressed,
    );
  }
}
