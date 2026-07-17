import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Overrides the app-data (settings) folder when set to a non-empty path.
/// Lets a dev or test run point the app at a disposable sandbox instead of
/// the real `%APPDATA%` folder. See `.vscode/launch.json` "(Sandbox)".
const String kAppDataDirEnvVar = 'CARDWAVE_APPDATA_DIR';

/// Overrides the *default* character-library folder when set to a non-empty
/// path. Only consulted while `settings.json` has no `character_path` yet
/// (fresh install / onboarding), same as the normal Documents default.
const String kLibraryDirEnvVar = 'CARDWAVE_LIBRARY_DIR';

Future<String> getNativeAppDataPath(String appName) async {
  final override = Platform.environment[kAppDataDirEnvVar];
  if (override != null && override.isNotEmpty) return override;
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
  final override = Platform.environment[kLibraryDirEnvVar];
  if (override != null && override.isNotEmpty) return override;
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
