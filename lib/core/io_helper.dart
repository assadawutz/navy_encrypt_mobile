import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
class IOHelper {
  static Future<File> saveBytes(String filename, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$filename');
    return f.writeAsBytes(bytes, flush: true);
  }
  static Future<void> preview(File f) async { await OpenFilex.open(f.path); }
  static Future<void> shareFile(File f) async { await Share.shareXFiles([XFile(f.path)]); }
}
