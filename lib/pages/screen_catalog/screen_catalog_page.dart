library screen_catalog_page;

import 'package:flutter/material.dart';
import 'package:navy_encrypt/common/header_scaffold.dart';
import 'package:navy_encrypt/common/my_state.dart';
import 'package:navy_encrypt/common/widget_view.dart';
import 'package:navy_encrypt/pages/cloud_picker/cloud_picker_page.dart';
import 'package:navy_encrypt/pages/decryption/decryption_page.dart';
import 'package:navy_encrypt/pages/encryption/encryption_page.dart';
import 'package:navy_encrypt/pages/file_viewer/file_viewer_page.dart';
import 'package:navy_encrypt/pages/history/history_page.dart';
import 'package:navy_encrypt/pages/home/home_page.dart';
import 'package:navy_encrypt/pages/result/result_page.dart';
import 'package:navy_encrypt/pages/settings/settings_page.dart';
import 'package:navy_encrypt/pages/splash/splash_page.dart';

part 'screen_catalog_page_view.dart';

class ScreenCatalogPage extends StatefulWidget {
  static const routeName = 'screen_catalog';

  const ScreenCatalogPage({Key key}) : super(key: key);

  @override
  ScreenCatalogPageController createState() => ScreenCatalogPageController();
}

class ScreenCatalogPageController extends MyState<ScreenCatalogPage> {
  List<_ScreenCatalogEntry> getEntries() {
    final entries = <_ScreenCatalogEntry>[
      _ScreenCatalogEntry(
        title: 'หน้าเริ่มต้น (Splash)',
        description: 'เตรียมระบบก่อนพาไปยังหน้าหลัก',
        icon: Icons.hourglass_bottom,
        routeName: SplashPage.routeName,
      ),
      _ScreenCatalogEntry(
        title: 'หน้าหลัก',
        description: 'ศูนย์รวมเมนูเลือกไฟล์และทางลัดทั้งหมด',
        icon: Icons.home_filled,
        routeName: HomePage.routeName,
      ),
      _ScreenCatalogEntry(
        title: 'เข้ารหัสไฟล์',
        description: 'เลือกไฟล์และใส่รหัสผ่านเพื่อสร้างไฟล์เข้ารหัส',
        icon: Icons.lock_outline,
        routeName: EncryptionPage.routeName,
      ),
      _ScreenCatalogEntry(
        title: 'ถอดรหัสไฟล์',
        description: 'ใช้ไฟล์ .enc ร่วมกับรหัสผ่านเพื่อคืนค่าเอกสาร',
        icon: Icons.lock_open,
        routeName: DecryptionPage.routeName,
      ),
      _ScreenCatalogEntry(
        title: 'ประวัติการใช้งาน',
        description: 'ติดตามรายการไฟล์ที่เคยแชร์หรือบันทึกไว้',
        icon: Icons.history,
        routeName: HistoryPage.routeName,
      ),
      _ScreenCatalogEntry(
        title: 'ตั้งค่าลายน้ำ',
        description: 'จัดการคีย์และการเปิดใช้งานระบบลายน้ำ',
        icon: Icons.settings,
        routeName: SettingsPage.routeName,
      ),
      _ScreenCatalogEntry(
        title: 'ตัวเลือกคลาวด์',
        description: 'ต้องเปิดจากเมนูเลือกไฟล์ในหน้าหลักเพื่อระบุปลายทาง',
        icon: Icons.cloud_outlined,
        routeName: CloudPickerPage.routeName,
        enabled: false,
        helperText: 'เปิดจากเมนู “ไฟล์ในเครื่อง / Google Drive / OneDrive”',
      ),
      _ScreenCatalogEntry(
        title: 'หน้าผลลัพธ์',
        description: 'จะแสดงหลังเข้ารหัสหรือถอดรหัสสำเร็จพร้อมข้อมูลไฟล์',
        icon: Icons.task_alt,
        routeName: ResultPage.routeName,
        enabled: false,
        helperText: 'รอให้ขั้นตอนเข้ารหัส/ถอดรหัสเสร็จก่อน',
      ),
      _ScreenCatalogEntry(
        title: 'ตัวดูไฟล์',
        description: 'แสดงไฟล์ที่ได้รับหลังถอดรหัสหรือจากหน้าผลลัพธ์',
        icon: Icons.visibility,
        routeName: FileViewerPage.routeName,
        enabled: false,
        helperText: 'เข้าผ่านหน้าผลลัพธ์หลังเลือกไฟล์',
      ),
    ];

    return entries;
  }

  void openRoute(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopLayout = constraints.maxWidth >= 900;
        return _ScreenCatalogPageView(
          this,
          isDesktopLayout: useDesktopLayout,
        );
      },
    );
  }
}

class _ScreenCatalogEntry {
  final String title;
  final String description;
  final IconData icon;
  final String routeName;
  final bool enabled;
  final String helperText;

  const _ScreenCatalogEntry({
    @required this.title,
    @required this.description,
    @required this.icon,
    @required this.routeName,
    this.enabled = true,
    this.helperText,
  });
}
