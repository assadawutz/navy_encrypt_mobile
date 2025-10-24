import 'dart:io';

Map<String, String> loadRuntimeEnvironment() {
  try {
    return Platform.environment;
  } catch (_) {
    return const {};
  }
}
