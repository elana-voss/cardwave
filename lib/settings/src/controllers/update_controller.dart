import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateController {
  const UpdateController._();

  static const String _releasesUrl =
      'https://github.com/elana-voss/cardwave/releases/latest';

  /// Runs the update check and drives the matching dialog through NavigationService.
  static Future<void> checkAndShow() async {
    final result = await UpdateService.fetchUpdateInfo();
    final nav = NavigationService();

    switch (result) {
      case UpdateAvailable(
        currentVersion: final current,
        latestVersion: final latest,
        releaseNotes: final notes,
      ):
        final viewReleases = await nav.showUpdateAvailableDialog(
          currentVersion: current,
          latestVersion: latest,
          releaseNotes: notes,
        );
        if (viewReleases) {
          await launchUrl(
            Uri.parse(_releasesUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      case UpToDate(version: final v):
        await nav.showAlertConfirmDialog(
          title: t.settings.updateCheck.upToDateTitle,
          message: t.settings.updateCheck.upToDateMessage(version: v),
        );
      case UpdateNotApplicable():
        await nav.showAlertConfirmDialog(
          title: t.settings.updateCheck.notApplicableTitle,
          message: t.settings.updateCheck.notApplicableMessage,
        );
      case UpdateCheckFailed(reason: final r):
        await nav.showAlertConfirmDialog(
          title: t.settings.updateCheck.errorTitle,
          message: r,
        );
    }
  }
}
