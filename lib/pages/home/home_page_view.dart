part of home_page;

class _HomePageView extends WidgetView<HomePage, HomePageController> {
  _HomePageView(HomePageController state) : super(state);

  static const _appVersion = 'เวอร์ชัน 4.2.0+5';

  @override
  Widget build(BuildContext context) {
    return HeaderScaffold(
      showBackButton: false,
      showProgress: state.isLoading,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/ic_launcher.png', height: 70.0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.0),
            child: Column(
              children: [
                Text(
                  'ระบบรับส่งไฟล์',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: DimensionUtil.isTallScreen(context) ? 34.0 : 28.0,
                    shadows: const [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 4.0,
                        color: Color.fromARGB(255, 60, 60, 60),
                      ),
                    ],
                  ),
                ),
                Text(
                  'SEND AND RECEIVE FILES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: DimensionUtil.isTallScreen(context) ? 22.0 : 20.0,
                    height: 0.9,
                    fontWeight: FontWeight.w400,
                    shadows: const [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 4.0,
                        color: Color.fromARGB(255, 60, 60, 60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      headerAssetPath: _getHeaderImageAsset(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final isSingleColumn = maxWidth < 520;
          final isTripleColumn = maxWidth >= 1024;
          final itemsPerRow = isTripleColumn
              ? 3
              : isSingleColumn
                  ? 1
                  : 2;
          final iconSize = maxWidth >= 1280
              ? 110.0
              : maxWidth >= 960
                  ? 100.0
                  : maxWidth >= 720
                      ? 92.0
                      : 82.0;
          final rows = <List<Map<String, dynamic>>>[];
          for (var i = 0; i < state._menuData.length; i += itemsPerRow) {
            rows.add(state._menuData.sublist(
              i,
              i + itemsPerRow > state._menuData.length
                  ? state._menuData.length
                  : i + itemsPerRow,
            ));
          }

          return Column(
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  _appVersion,
                  style: const TextStyle(fontSize: 18.0),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getHeaderImageAsset(BuildContext context) {
    final ratio = screenRatio(context);
    if (ratio >= 2.0) {
      return 'assets/images/bg_header_home_2.png';
    } else if (ratio >= 1.8) {
      return 'assets/images/bg_header_home_3.png';
    } else {
      return 'assets/images/bg_header_home_4.png';
    }
  }
}

class MenuItem extends StatelessWidget {
  final String image;
  final String text;
  final Function onClick;
  final double size;
  final double borderWidth;

  const MenuItem({
    this.image,
    this.text,
    this.onClick,
    this.size,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onClick,
      highlightColor: Colors.lightBlueAccent.withOpacity(0.05),
      splashColor: Colors.lightBlueAccent.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: size ??
                  (screenHeight(context) > 800 || Platform.isWindows
                      ? 90.0
                      : 80.0),
              height: size ??
                  (screenHeight(context) > 800 || Platform.isWindows
                      ? 90.0
                      : 80.0),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: borderWidth ?? 4.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    offset: Offset(0.0, 4.0),
                    blurRadius: 10.0,
                    color: Color.fromRGBO(25, 25, 25, 0.2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset(
                  image,
                  color: onClick == null ? const Color(0xFFC4C4C4) : null,
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              text ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size != null && size > 100 ? 26.0 : 22.0,
                fontWeight: FontWeight.w400,
                color: onClick == null ? const Color(0xFFC4C4C4) : const Color(0xFF1F1F1F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
