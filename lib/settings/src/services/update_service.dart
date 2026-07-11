import 'dart:convert';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable({
    required this.currentVersion,
    required this.latestVersion,
    this.releaseNotes,
  });
  final String currentVersion;
  final String latestVersion;
  final String? releaseNotes;
}

class UpToDate extends UpdateCheckResult {
  const UpToDate(this.version);
  final String version;
}

class UpdateNotApplicable extends UpdateCheckResult {
  const UpdateNotApplicable();
}

class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.reason);
  final String reason;
}

class UpdateService {
  /// Fetches the latest version metadata from the server and compares it to
  /// the running build. Pure: no UI, no context, no dialogs.
  static Future<UpdateCheckResult> fetchUpdateInfo() async {
    if (kIsWeb) return const UpdateNotApplicable();

    try {
      final response = await http
          .get(Uri.parse(AppConstants.version))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return UpdateCheckFailed(t.settings.updateCheck.serverErrorMessage);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['latest_version'] as String;

      final packageInfo = await PackageInfo.fromPlatform();
      var currentFullVersion = packageInfo.version;
      if (packageInfo.buildNumber.isNotEmpty) {
        currentFullVersion += '+${packageInfo.buildNumber}';
      }

      if (_isNewerVersion(currentFullVersion, latestVersion)) {
        final releaseNotes = data['release_notes'] as String?;
        return UpdateAvailable(
          currentVersion: currentFullVersion,
          latestVersion: latestVersion,
          releaseNotes: releaseNotes,
        );
      }
      return UpToDate(currentFullVersion);
    } on Exception catch (e, st) {
      LoggingService().error('Update check failed', e, st);
      return UpdateCheckFailed(t.settings.updateCheck.connectionErrorMessage);
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    return Version.parse(latest) > Version.parse(current);
  }
}
