part of screen_catalog_page;

class _ScreenCatalogPageView
    extends WidgetView<ScreenCatalogPage, ScreenCatalogPageController> {
  final bool isDesktopLayout;

  _ScreenCatalogPageView(
    ScreenCatalogPageController state, {
    this.isDesktopLayout = false,
  }) : super(state);

  @override
  Widget build(BuildContext context) {
    final entries = state.getEntries();
    final padding = isDesktopLayout ? const EdgeInsets.all(32.0) : const EdgeInsets.all(24.0);

    return HeaderScaffold(
      showBackButton: true,
      showSettingsButton: false,
      header: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Icon(
              Icons.dashboard_customize,
              size: isDesktopLayout ? 72.0 : 60.0,
              color: Colors.white,
            ),
          ),
          Text(
            'หน้าจอทั้งหมด',
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktopLayout ? 34.0 : 28.0,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  offset: const Offset(1.0, 1.0),
                  blurRadius: 4.0,
                  color: Colors.black.withOpacity(0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'เลือกหน้าที่ต้องการทดสอบหรืออ่านคำแนะนำได้จากที่เดียว',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isDesktopLayout ? 20.0 : 18.0,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktopLayout ? 900.0 : double.infinity,
          ),
          child: ListView.separated(
            padding: padding,
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16.0),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _ScreenEntryCard(
                entry: entry,
                onTap: entry.enabled
                    ? () => state.openRoute(context, entry.routeName)
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScreenEntryCard extends StatelessWidget {
  final _ScreenCatalogEntry entry;
  final VoidCallback onTap;

  const _ScreenEntryCard({
    Key key,
    @required this.entry,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final theme = Theme.of(context);

    return Card(
      elevation: 3.0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54.0,
                height: 54.0,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? theme.primaryColor.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  entry.icon,
                  size: 28.0,
                  color: isEnabled ? theme.primaryColor : Colors.grey,
                ),
              ),
              const SizedBox(width: 20.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.headline6.copyWith(
                        color: isEnabled ? theme.textTheme.headline6.color : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      entry.description,
                      style: theme.textTheme.subtitle1.copyWith(
                        color: isEnabled
                            ? theme.textTheme.subtitle1.color
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (entry.helperText != null && entry.helperText.isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 12.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 18.0, color: Colors.orange),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                entry.helperText,
                                style: theme.textTheme.bodyText2.copyWith(
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isEnabled) ...[
                const SizedBox(width: 16.0),
                Icon(Icons.chevron_right, color: theme.primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
