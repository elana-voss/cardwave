import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
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
              title: const Text('Character Folder'),
              subtitle: Text(
                settings.characterPath != null &&
                        settings.characterPath!.isNotEmpty
                    ? settings.characterPath!
                    : 'Not set. Required for the app to function.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: settings.characterPath == null
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
              trailing: ElevatedButton(
                onPressed: _pickDirectory,
                child: const Text('Browse...'),
              ),
            ),
            if (kDebugMode)
              ListTile(
                leading: const Icon(Icons.tag_sharp),
                title: const Text('Taxonomy Tags'),
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
              title: const Text('App Theme'),
              trailing: Padding(
                padding: EdgeInsets.zero,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto, size: 18),
                      label: isNarrow ? null : const Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode, size: 18),
                      label: isNarrow ? null : const Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode, size: 18),
                      label: isNarrow ? null : const Text('Dark'),
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
              title: const Text('Theme Style'),
              trailing: SegmentedButton<ThemeStyleEnum>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeStyleEnum.standard,
                    icon: const Icon(Icons.format_paint, size: 18),
                    label: isNarrow ? null : const Text('Default'),
                  ),
                  ButtonSegment(
                    value: ThemeStyleEnum.neon,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: isNarrow ? null : const Text('Neon'),
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
              title: const Text('Story Memory'),
              subtitle: const Text(
                'Remember earlier moments and bring the relevant ones back '
                'into long chats.',
              ),
              value: settings.memoryEnabled,
              onChanged: (value) {
                settings.memoryEnabled = value;
                unawaited(settingsService.saveSettings());
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_stories),
              title: const Text('Narrative Engine'),
              subtitle: const Text(
                'Track the scene and characters and move the story along as '
                'you chat.',
              ),
              value: settings.nodesEnabled,
              onChanged: (value) {
                settings.nodesEnabled = value;
                unawaited(settingsService.saveSettings());
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.data_usage),
              title: const Text('Show Prompt Breakdown'),
              subtitle: const Text(
                'Show a bar under each reply breaking down how the prompt '
                'filled the model context window.',
              ),
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
              title: const Text('Check for Updates'),
              subtitle: const Text(
                'Check if a newer version of the app is available.',
              ),
              onTap: () => unawaited(UpdateController.checkAndShow()),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Website'),
              subtitle: const Text(
                'Visit the official website for updates and information.',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(Uri.parse(AppConstants.website)),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: const Text('Disclaimer & Terms'),
              subtitle: const Text(
                'Read the application disclaimer and terms of use.',
              ),
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
                  'Version ${snapshot.requireData.version}+${snapshot.requireData.buildNumber}',
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
