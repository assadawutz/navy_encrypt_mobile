part of home_page;

class _HomePageViewWin extends WidgetView<HomePage, HomePageController> {
  _HomePageViewWin(HomePageController state) : super(state);

  static const _appVersion = 'เวอร์ชัน 4.2.0+5';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeaderScaffold(
        showBackButton: false,
        showProgress: state.isLoading,
        progressMessage: state.loadingMessage,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isLargeDesktop = width >= 1600;
            final itemsPerRow = width >= 1280
                ? 4
                : width >= 1024
                    ? 3
                    : width >= 720
                        ? 2
                        : 1;
            final iconSize = isLargeDesktop
                ? 120.0
                : width >= 1400
                    ? 110.0
                    : width >= 1200
                        ? 100.0
                        : width >= 900
                            ? 92.0
                            : 86.0;

            final rows = <List<Map<String, dynamic>>>[];
            for (var i = 0; i < state._menuData.length; i += itemsPerRow) {
              rows.add(state._menuData.sublist(
                i,
                i + itemsPerRow > state._menuData.length
                    ? state._menuData.length
                    : i + itemsPerRow,
              ));
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                width * 0.08,
                height > 840 ? height * 0.08 : 32.0,
                width * 0.08,
                24.0,
              ),
              child: Column(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/ic_launcher.png',
                        height: isLargeDesktop ? 120.0 : 90.0,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          children: [
                            Text(
                              'ระบบรับส่งไฟล์',
                              style: TextStyle(
                                color: const Color(0xFF333333),
                                fontSize: isLargeDesktop ? 48.0 : 34.0,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              'SEND AND RECEIVE FILES',
                              style: TextStyle(
                                color: const Color(0xFF333333),
                                fontSize: isLargeDesktop ? 32.0 : 22.0,
                                height: 0.9,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),
                  Expanded(
                    child: Column(
                      children: [
                        for (final row in rows)
                          Expanded(
                            child: Row(
                              children: [
                                for (var j = 0; j < itemsPerRow; j++)
                                  Expanded(
                                    child: j < row.length
                                        ? MenuItem(
                                            text: row[j]['text'],
                                            image: row[j]['image'],
                                            size: iconSize,
                                            borderWidth: isLargeDesktop ? 5.0 : 4.0,
                                            onClick: row[j]['onClick'] == null
                                                ? null
                                                : () {
                                                    row[j]['onClick'](context);
                                                  },
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _appVersion,
                    style: const TextStyle(fontSize: 18.0),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
