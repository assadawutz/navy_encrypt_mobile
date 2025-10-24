import 'package:flutter/foundation.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform({@required this.tempPath, @required this.documentsPath})
      : assert(tempPath != null && tempPath != ''),
        assert(documentsPath != null && documentsPath != '');

  final String tempPath;
  final String documentsPath;

  @override
  Future<String> getTemporaryPath() async => tempPath;

  @override
  Future<String> getApplicationDocumentsPath() async => documentsPath;
}
