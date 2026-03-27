import 'dart:io';

bool isWslRuntime() {
  if (!Platform.isLinux) {
    return false;
  }

  if (Platform.environment.containsKey('WSL_DISTRO_NAME')) {
    return true;
  }

  try {
    final version = File('/proc/version').readAsStringSync().toLowerCase();
    return version.contains('microsoft');
  } catch (_) {
    return false;
  }
}
