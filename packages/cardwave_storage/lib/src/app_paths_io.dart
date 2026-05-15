import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> getNativeAppDataPath(String appName) async {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      return '$appData${Platform.pathSeparator}${appName}_Editor';
    }
  } else if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
  // Fallback for non-windows native dev
  return Directory.current.path;
}

Future<String> getNativeDefaultCharacterPath(String appName) async {
  String? docPath;
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      docPath = '$userProfile${Platform.pathSeparator}Documents';
    }
  } else if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  } else {
    final home = Platform.environment['HOME'];
    if (home != null) {
      docPath = '$home${Platform.pathSeparator}Documents';
    }
  }

  if (docPath == null) return Directory.current.path;

  return '$docPath${Platform.pathSeparator}$appName';
}
