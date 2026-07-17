import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/controllers/update_controller.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsTabGeneral extends StatefulWidget {
  const SettingsTabGeneral({super.key});

  @override
  State<SettingsTabGeneral> createState() => _SettingsTabGeneralState();
}

class _SettingsTabGeneralState extends State<SettingsTabGeneral> {
  // Resolved once, not re-fetched on every rebuild — the `package_info_plus`
  // plugin memoises the platform call anyway, but the FutureBuilder needs a
  // stable Future to avoid re-running its builder.
  final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  Future<void> _pickDirectory() async {
    final settingsService = context.read<SettingsService>();
    final directoryPath = await getDirectoryPath(
      initialDirectory: settingsService.settings.characterPath,
    );
    if (directoryPath != null && mounted) {
      settingsService.settings.characterPath = directoryPath;
      await settingsService.saveSettings();

      if (mounted) {
        await context.read<CharacterService>().loadCharacters();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final settings = settingsService.settings;
    final settingsDisplay = context.watch<ThemeNotifier>();
    final currentMode = settingsDisplay.themeMode;
    // Below the mobile breakpoint the ListTile trailing slot can't fit
    // a 3-segment labeled SegmentedButton — Flutter throws a layout
    // assertion ("Trailing widget consumes the entire tile width") and
    // the dialog never paints. Drop the per-segment text labels on
    // narrow viewports; the icons are recognisable on their own.
    final isNarrow =
        MediaQuery.sizeOf(context).width <= AppConstants.mobileBreakpoint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        _MenuGroupCard(
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(t.settings.general.characterFolderTitle),
              subtitle: Text(
                settings.characterPath != null &&
                        settings.characterPath!.isNotEmpty
                    ? settings.characterPath!
                    : t.settings.general.characterFolderNotSet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: settings.characterPath == null
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
              trailing: ElevatedButton(
                onPressed: _pickDirectory,
                child: Text(t.settings.general.browseButton),
              ),
            ),
            if (kDebugMode)
              ListTile(
                leading: const Icon(Icons.tag_sharp),
                title: Text(t.settings.general.taxonomyTagsTitle),
                onTap: () =>
                    unawaited(NavigationService().showTaxonomyEditorDialog()),
              ),
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : currentMode == ThemeMode.light
                    ? Icons.light_mode
                    : Icons.brightness_auto,
              ),
              title: Text(t.settings.general.appThemeTitle),
              trailing: Padding(
                padding: EdgeInsets.zero,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto, size: 18),
                      label: isNarrow
                          ? null
                          : Text(t.settings.general.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode, size: 18),
                      label: isNarrow
                          ? null
                          : Text(t.settings.general.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode, size: 18),
                      label: isNarrow
                          ? null
                          : Text(t.settings.general.themeDark),
                    ),
                  ],
                  selected: {currentMode},
                  onSelectionChanged: (newSelection) {
                    final newMode = newSelection.first;
                    settingsDisplay.themeMode = newMode;
                    settingsService.settings.themeMode = newMode;
                    unawaited(settingsService.saveSettings());
                  },
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(t.settings.general.themeStyleTitle),
              trailing: SegmentedButton<ThemeStyleEnum>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeStyleEnum.standard,
                    icon: const Icon(Icons.format_paint, size: 18),
                    label: isNarrow
                        ? null
                        : Text(t.settings.general.themeStyleDefault),
                  ),
                  ButtonSegment(
                    value: ThemeStyleEnum.neon,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: isNarrow
                        ? null
                        : Text(t.settings.general.themeStyleNeon),
                  ),
                ],
                selected: {settingsDisplay.themeStyle},
                onSelectionChanged: (newSelection) {
                  settingsDisplay.themeStyle = newSelection.first;
                  settingsService.settings.themeStyle = newSelection.first;
                  unawaited(settingsService.saveSettings());
                },
              ),
            ),
          ],
        ),
        _MenuGroupCard(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.psychology),
              title: Text(t.settings.general.storyMemoryTitle),
              subtitle: Text(t.settings.general.storyMemorySubtitle),
              value: settings.memoryEnabled,
              onChanged: (value) {
                settings.memoryEnabled = value;
                unawaited(settingsService.saveSettings());
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.data_usage),
              title: Text(t.settings.general.promptBreakdownTitle),
              subtitle: Text(t.settings.general.promptBreakdownSubtitle),
              value: settings.showPromptBreakdown,
              onChanged: (value) {
                settings.showPromptBreakdown = value;
                unawaited(settingsService.saveSettings());
              },
            ),
          ],
        ),
        _MenuGroupCard(
          children: [
            ListTile(
              leading: const Icon(Icons.system_update),
              title: Text(t.settings.general.checkUpdatesTitle),
              subtitle: Text(t.settings.general.checkUpdatesSubtitle),
              onTap: () => unawaited(UpdateController.checkAndShow()),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(t.settings.general.websiteTitle),
              subtitle: Text(t.settings.general.websiteSubtitle),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(Uri.parse(AppConstants.website)),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text(t.settings.general.disclaimerTitle),
              subtitle: Text(t.settings.general.disclaimerSubtitle),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(Uri.parse(AppConstants.disclaimer)),
            ),
          ],
        ),
        FutureBuilder<PackageInfo>(
          future: _packageInfoFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.settings.general.versionLabel(
                    version: snapshot.requireData.version,
                    buildNumber: snapshot.requireData.buildNumber,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _MenuGroupCard extends StatelessWidget {
  const _MenuGroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
