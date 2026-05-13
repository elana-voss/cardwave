import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/pages/widgets/dialog_provider_config.dart'
    show DialogProviderAddResult;
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

/// Stateless orchestrator for the LLM provider profiles (the "AI Providers"
/// list inside `SettingsTabAi` and the per-row tile in `TileProviderProfile`).
/// Hosts the add and edit flows; the widget owns its own loading-state
/// `setState` because that's UI chrome, not domain logic.
///
/// Add is intentionally split into [openProviderAddDialog] (returns the
/// raw result) and [applyProviderAdd] (does the persistence) so the widget
/// can flip its spinner *after* the dialog closes — the existing UX only
/// shows "Adding provider..." during the post-dialog model refresh, not
/// while the user is still filling out the dialog.
class ProvidersController {
  const ProvidersController._();

  /// Opens the provider add dialog. Returns the dialog's result on save,
  /// null on cancel.
  static Future<DialogProviderAddResult?> openProviderAddDialog({
    required bool isLocal,
  }) {
    return NavigationService().showProviderAddDialog(isLocal: isLocal);
  }

  /// Persists a confirmed provider add: appends [added].profile to settings,
  /// refreshes the new provider's model roster (using the dialog's
  /// pre-fetched models so the network round-trip already paid for inside
  /// the dialog isn't done a second time), heals domain→preset assignments,
  /// and saves.
  static Future<void> applyProviderAdd({
    required SettingsService settingsService,
    required LlmManagementService mgmt,
    required DialogProviderAddResult added,
  }) async {
    settingsService.settings.providerConfigs.add(added.profile);
    await mgmt.refreshProviderModels(
      settings: settingsService.settings,
      profile: added.profile,
      trigger: ModelRefreshTriggerEnum.manual,
      preFetchedModels: added.fetchedModels,
    );
    mgmt.healDomainAssignments(settings: settingsService.settings);
    await settingsService.saveSettings();
  }

  /// Opens the edit dialog for [profile] and persists the result. Replaces
  /// `providerConfigs[index]` with the returned profile, heals domain→preset
  /// assignments, and saves. Returns true if an edit committed, false on
  /// cancel.
  static Future<bool> editProvider({
    required SettingsService settingsService,
    required LlmManagementService mgmt,
    required LlmProviderConfig profile,
    required int index,
  }) async {
    final newProfile = await NavigationService().showProviderEditDialog(
      profile: profile,
    );
    if (newProfile == null) return false;
    // `index` is the position the edit dialog was opened for.
    // ignore: qcheck/avoid_unsafe_collection_methods
    settingsService.settings.providerConfigs[index] = newProfile;
    mgmt.healDomainAssignments(settings: settingsService.settings);
    await settingsService.saveSettings();
    return true;
  }
}
