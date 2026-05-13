import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RouteEditPreset {
  Future<void> execute(BuildContext context, String presetId) async {
    try {
      if (context.mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final currentRoute = ModalRoute.of(context);

        if (currentRoute is PopupRoute) {
          navigator.pop();
        }

        final settingsService = navigator.context.read<SettingsService>();
        final pureHelpers = navigator.context.read<LlmPureHelpers>();
        final mgmt = navigator.context.read<LlmManagementService>();
        final profiles = settingsService.settings.providerConfigs;

        final resolved = pureHelpers.resolvePresetOrNull(
          configId: presetId,
          providers: profiles,
        );
        if (resolved == null) throw Exception('Preset not found');
        final targetProfile = resolved.provider;
        final targetModel = resolved.model;
        final targetPreset = resolved.preset;

        final settings = settingsService.settings;
        final activeDomains = <LlmProviderDomainEnum>{
          for (final d in LlmProviderDomainEnum.values)
            if (settings.getAppDomainPresetId(d) == presetId) d,
        };

        final result = await NavigationService().showPresetConfigDialog(
          configuration: targetPreset,
          connectionProfile: targetProfile,
          initialModel: targetModel,
          activeDomains: activeDomains,
        );

        if (result != null) {
          mgmt.applyPresetEdit(
            provider: targetProfile,
            targetModel: result.model,
            preset: result.preset,
            previousModel: targetModel,
            previousPreset: targetPreset,
          );
          await settingsService.saveSettings();
        }
      }
    } on Exception catch (e, st) {
      LoggingService().error(
        'Navigation error to edit preset: $presetId',
        e,
        st,
      );
      NavigationService().showSnackBar(
        'Navigation error to edit preset: $presetId',
      );
    }
  }
}
