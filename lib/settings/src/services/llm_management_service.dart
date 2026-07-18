import 'dart:async' show unawaited;

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/models/app_settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';

typedef RefreshSummary = ({
  int updated,
  int rematched,
  int markedUnavailable,
  Map<String, String> errorsByProfile,
});

typedef ProfileRefreshResult = ({
  int updated,
  int rematched,
  int markedUnavailable,
  String? error,
});

/// Mutates `AppSettings.providerConfigs` and `AppSettings.domainPresetIds`
/// — refresh, profile/preset add/edit/delete, domain assignment heal.
/// All write paths funnel through here so the disk-save trigger is owned
/// by `SettingsService` (which calls `saveSettings()` after the mutation).
///
/// The pure read/lookup/runner-build side lives in [LlmPureHelpers]; this
/// service holds a reference to it so refresh-and-seed flows can call into
/// the same canonical-name and resolve helpers the rest of the app uses.
class LlmManagementService {
  LlmManagementService({required LlmPureHelpers pureHelpers})
    : _pureHelpers = pureHelpers;
  final LlmPureHelpers _pureHelpers;

  /// Reassigns every domain to [profile]'s canonical defaults, overwriting
  /// existing assignments even if they point at a different provider.
  /// For each domain:
  ///   - resolves the provider's default model (with capability fallback,
  ///     mirroring the add-provider seed path);
  ///   - reuses the default preset on that model identified by its
  ///     canonical name `'${domain.label} · $providerLabel'` (the same
  ///     string the add-provider path seeds at onboarding). Name-matched —
  ///     preset ids carry a random suffix so id-matching would mint
  ///     duplicates on every press;
  ///   - creates a fresh default preset if no canonical-name match exists
  ///     (user deleted or renamed it);
  ///   - clears the assignment when no adopted model can serve the domain
  ///     (e.g. image domain on a text-only provider).
  void resetDomainsToProviderDefaults({
    required AppSettings settings,
    required LlmProviderConfig profile,
  }) {
    final providerInfo = LlmProvider.of(profile.providerEnum);
    final providerLabel = providerInfo.label;

    for (final domain in LlmProviderDomainEnum.values) {
      final resolvedId = _pureHelpers.resolveDefaultModelForDomain(
        profile.providerEnum,
        domain,
        profile.models,
      );
      if (resolvedId.isEmpty) {
        settings.domainPresetIds.remove(domain);
        continue;
      }
      final hostModel = profile.models.firstWhere(
        (m) => m.id == resolvedId,
        orElse: () =>
            throw StateError('resolved model "$resolvedId" not in profile'),
      );
      final canonicalName = _pureHelpers.canonicalDefaultPresetName(
        domain,
        providerLabel,
      );
      final existing = hostModel.presets
          .where((p) => p.name == canonicalName)
          .firstOrNull;
      final String presetId;
      if (existing != null) {
        presetId = existing.id;
      } else {
        presetId = UtilsId.generateId('${resolvedId}_${domain.name}');
        hostModel.presets.add(
          LlmPresetConfig(
            id: presetId,
            name: canonicalName,
            parameterValues: {
              LlmParameterDefinitionIdEnum.maxResponseLength:
                  AppConstants.defaultMaxResponseTokens,
              LlmParameterDefinitionIdEnum.temperature:
                  domain.defaultTemperature,
            },
          ),
        );
      }
      settings.setAppDomainPresetId(domain, presetId);
    }
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message: 'resetDomainsToProviderDefaults: provider=${profile.id}',
      ),
    );
  }

  /// For each domain, assigns the matching preset id from [domainConfigIds]
  /// into [settings] iff that domain currently has no preset.
  void assignDefaultDomainPresetsIfEmpty({
    required AppSettings settings,
    required Map<LlmProviderDomainEnum, String> domainConfigIds,
  }) {
    for (final entry in domainConfigIds.entries) {
      if (settings.getAppDomainPresetId(entry.key) == null) {
        settings.setAppDomainPresetId(entry.key, entry.value);
      }
    }
  }

  /// Single entry point used by all four triggers that write the catalog
  /// into settings.json (app-start daily refresh, onboarding, add-provider,
  /// manual refresh). Fetches the provider's full model list, merges it
  /// into [profile.models] preserving user presets, enriches each model's
  /// TTS/video/image option rosters, and seeds default domain presets if
  /// the profile has none yet. Per-profile try/catch so one bad provider
  /// doesn't sink a bulk refresh. Caller is responsible for persisting via
  /// `SettingsService.saveSettings()`.
  ///
  /// [preFetchedModels] lets onboarding and add-provider skip a redundant
  /// second fetch — their UI already pulled the list for the picker.
  /// Refresh passes null and the helper fetches itself.
  Future<ProfileRefreshResult> refreshProviderModels({
    required AppSettings settings,
    required LlmProviderConfig profile,
    required ModelRefreshTriggerEnum trigger,
    List<LlmModel>? preFetchedModels,
  }) async {
    // In-process GGUF profiles have no remote catalog — the model IS the
    // file the user picked. Skip the fetch + rebuild path (it would call
    // fetchModels(baseUrl: null) and drop the model when its preset list
    // is empty). Still run the preset-seeding step so a fresh add yields
    // a usable chat-domain preset; otherwise the profile renders as
    // "No Models configured" in the providers list.
    if (profile.providerEnum == LLMProviderEnum.localGguf) {
      _seedDefaultDomainPresetsIfEmpty(settings: settings, profile: profile);
      return (
        updated: 0,
        rematched: 0,
        markedUnavailable: 0,
        error: null,
      );
    }
    final label =
        '${profile.providerEnum.name} (profile ${profile.id}) '
        '[trigger: ${trigger.label}]';
    var updated = 0;
    var added = 0;
    var rematched = 0;
    var markedUnavailable = 0;
    try {
      final fresh =
          preFetchedModels ??
          await _pureHelpers.fetchModels(
            provider: profile.providerEnum,
            apiKey: profile.apiKey,
            baseUrl: profile.baseUrl,
            requireZdr: profile.requireZdr,
          );
      final freshById = {for (final m in fresh) m.id: m};
      final adoptedById = {for (final m in profile.models) m.id: m};

      final rebuilt = <LlmModel>[];
      for (final m in fresh) {
        final replacement = LlmModel.clone(m);
        final adopted = adoptedById[m.id];
        if (adopted != null) {
          replacement.presets = adopted.presets;
          final wasUnavailable = adopted.isUnavailable;
          replacement.isUnavailable = false;
          if (wasUnavailable) {
            rematched++;
          } else {
            updated++;
          }
        } else {
          added++;
        }
        rebuilt.add(replacement);
      }
      // Models in the old list that disappeared from the fresh catalog.
      // Keep those with presets (flagged unavailable so UI greys them out,
      // presets stay pointable); drop catalog-only ghosts.
      for (final adopted in profile.models) {
        if (freshById.containsKey(adopted.id)) continue;
        if (adopted.presets.isEmpty) continue;
        final wasAlreadyUnavailable = adopted.isUnavailable;
        adopted.isUnavailable = true;
        if (!wasAlreadyUnavailable) markedUnavailable++;
        rebuilt.add(adopted);
      }
      profile.models = rebuilt;

      await _pureHelpers.populateTtsVoices(profile);
      _pureHelpers.populateVideoOptions(profile);
      _pureHelpers.populateImageOptions(profile);
      _seedDefaultDomainPresetsIfEmpty(settings: settings, profile: profile);

      modelsLogger.info(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.info,
          message:
              'refreshProviderModels — $label: $updated refreshed, $added added, '
              '$rematched rematched, $markedUnavailable newly unavailable '
              '(${profile.models.length} total).',
        ),
      );
      return (
        updated: updated + added,
        rematched: rematched,
        markedUnavailable: markedUnavailable,
        error: null,
      );
    } on Exception catch (e, st) {
      // Local backend unreachable (kobold/llama.cpp not started) is a
      // lifecycle state — log as info so it stays out of the error overlay.
      final isLocalOffline =
          profile.providerEnum == LLMProviderEnum.localOpenAi &&
          e is LlmFetchException &&
          e.statusCode == null;
      final event = LlmDiagnosticEvent(
        level: isLocalOffline
            ? LlmDiagnosticLevel.info
            : LlmDiagnosticLevel.error,
        message: 'refreshProviderModels failed — $label',
        error: e,
        stackTrace: st,
      );
      if (isLocalOffline) {
        modelsLogger.info(event);
      } else {
        modelsLogger.severe(event);
      }
      return (
        updated: 0,
        rematched: 0,
        markedUnavailable: 0,
        error: e.toString(),
      );
    }
  }

  /// Creates canonical default presets for each domain on a profile that
  /// has no presets yet, then assigns them to [settings.domainPresetIds]
  /// for any domain currently unassigned. No-op when the profile already
  /// has presets — makes the outer helper idempotent across refresh calls.
  void _seedDefaultDomainPresetsIfEmpty({
    required AppSettings settings,
    required LlmProviderConfig profile,
  }) {
    if (profile.allPresets.isNotEmpty) return;
    final providerInfo = LlmProvider.of(profile.providerEnum);
    final providerLabel = providerInfo.label;
    final domainConfigIds = <LlmProviderDomainEnum, String>{};

    for (final domain in LlmProviderDomainEnum.values) {
      final resolvedId = _pureHelpers.resolveDefaultModelForDomain(
        profile.providerEnum,
        domain,
        profile.models,
      );
      if (resolvedId.isEmpty) continue;

      final host = profile.models.firstWhere(
        (m) => m.id == resolvedId,
        orElse: () =>
            throw StateError('resolved model "$resolvedId" not in profile'),
      );
      final presetId = UtilsId.generateId('${resolvedId}_${domain.name}');
      host.presets.add(
        LlmPresetConfig(
          id: presetId,
          name: _pureHelpers.canonicalDefaultPresetName(domain, providerLabel),
          parameterValues: {
            LlmParameterDefinitionIdEnum.maxResponseLength:
                AppConstants.defaultMaxResponseTokens,
            LlmParameterDefinitionIdEnum.temperature: domain.defaultTemperature,
          },
        ),
      );
      domainConfigIds[domain] = presetId;
    }
    assignDefaultDomainPresetsIfEmpty(
      settings: settings,
      domainConfigIds: domainConfigIds,
    );
  }

  /// Per-profile try/catch so one bad provider doesn't sink the others.
  /// Presets are preserved verbatim — user state. Also stamps
  /// `settings.lastModelRefreshAtMillis`; caller is responsible for
  /// persisting via `SettingsService.saveSettings()`.
  Future<RefreshSummary> refreshAdoptedModelMetadata({
    required AppSettings settings,
    required ModelRefreshTriggerEnum trigger,
  }) async {
    final profiles = settings.providerConfigs;
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'Model refresh started (trigger: ${trigger.label}) — '
            '${profiles.length} profile(s).',
      ),
    );

    final perProfile = await Future.wait([
      for (final profile in profiles)
        refreshProviderModels(
          settings: settings,
          profile: profile,
          trigger: trigger,
        ),
    ]);

    var totalUpdated = 0;
    var totalRematched = 0;
    var totalMarkedUnavailable = 0;
    final errors = <String, String>{};
    for (var i = 0; i < perProfile.length; i++) {
      final r = perProfile[i];
      totalUpdated += r.updated;
      totalRematched += r.rematched;
      totalMarkedUnavailable += r.markedUnavailable;
      // `perProfile` has one entry per profile (built by `Future.wait` over
      // `profiles`), so `i` indexes both.
      // ignore: qcheck/avoid_unsafe_collection_methods
      if (r.error != null) errors[profiles[i].id] = r.error!;
    }

    settings.lastModelRefreshAtMillis = DateTime.now().millisecondsSinceEpoch;

    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'Model refresh finished (trigger: ${trigger.label}) — '
            '$totalUpdated refreshed, $totalRematched rematched, '
            '$totalMarkedUnavailable newly unavailable, '
            '${errors.length} profile error(s).',
      ),
    );

    return (
      updated: totalUpdated,
      rematched: totalRematched,
      markedUnavailable: totalMarkedUnavailable,
      errorsByProfile: errors,
    );
  }

  /// Applies a preset edit/add to a provider: removes the old preset from
  /// its previous model, prunes that model if it has no presets left, then
  /// attaches the new preset to the target model (reusing the existing
  /// entry or snapshotting a fresh clone). Shared by preset-edit routes.
  void applyPresetEdit({
    required LlmProviderConfig provider,
    required LlmModel targetModel,
    required LlmPresetConfig preset,
    LlmModel? previousModel,
    LlmPresetConfig? previousPreset,
  }) {
    if (previousPreset != null && previousModel != null) {
      previousModel.presets.removeWhere((p) => p.id == previousPreset.id);
    }
    final host = provider.models.firstWhere(
      (m) => m.id == targetModel.id,
      orElse: () => throw StateError(
        'applyPresetEdit: target model "${targetModel.id}" not in provider '
        '"${provider.id}"',
      ),
    );
    host.presets.add(preset);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'applyPresetEdit: provider=${provider.id} model=${targetModel.id} '
            'preset=${preset.id}/"${preset.name}" '
            'previous=${previousPreset?.id ?? "none"}',
      ),
    );
  }

  void assignDomainPreset({
    required AppSettings settings,
    required LlmProviderDomainEnum domain,
    required String presetId,
  }) {
    final previousId = settings.getAppDomainPresetId(domain);
    settings.setAppDomainPresetId(domain, presetId);
    modelsLogger.info(
      LlmDiagnosticEvent(
        level: LlmDiagnosticLevel.info,
        message:
            'assignDomainPreset: domain=${domain.name} preset=$presetId '
            'previous=${previousId ?? "none"}',
      ),
    );
  }

  bool healDomainAssignments({required AppSettings settings}) {
    var mutated = false;
    final profiles = settings.providerConfigs;
    for (final domain in LlmProviderDomainEnum.values) {
      final validPresets = _pureHelpers.getValidPresetsForDomain(
        domain,
        profiles,
      );
      final validIds = validPresets.map((e) => e.config.id).toSet();
      final currentId = settings.getAppDomainPresetId(domain);
      if (currentId != null && validIds.contains(currentId)) continue;

      final fallbackId = (!domain.isOptional && validPresets.isNotEmpty)
          ? validPresets.first.config.id
          : null;
      if (currentId == fallbackId) continue;

      settings.setAppDomainPresetId(domain, fallbackId);
      modelsLogger.info(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.info,
          message:
              'healDomainAssignments: domain=${domain.name} '
              'previous=${currentId ?? "none"} new=${fallbackId ?? "none"}',
        ),
      );
      mutated = true;
    }
    return mutated;
  }

  /// Removes the provider and all its presets, then clears any app-level
  /// domain assignment pointing at a dropped preset. Character/session
  /// layers are deliberately left to lazy degradation in the resolver —
  /// sweeping them on every delete would mean walking every chat JSON on
  /// disk.
  void deleteProvider({
    required AppSettings settings,
    required String providerId,
  }) {
    final matching = settings.providerConfigs
        .where((p) => p.id == providerId)
        .toList();
    final dropped = matching
        .expand((p) => p.allPresets)
        .map((c) => c.id)
        .toSet();
    // For an in-process GGUF profile, free its plugin (and VRAM) before
    // we drop the profile that references it; otherwise the plugin sits
    // in the per-runtime cache with no owner until app restart.
    for (final p in matching) {
      if (p.providerEnum == LLMProviderEnum.localGguf &&
          p.modelPath != null) {
        unawaited(LlmProvider.disposeRuntimeFor(p.modelPath!));
      }
    }
    final lengthBefore = settings.providerConfigs.length;
    settings.providerConfigs.removeWhere((p) => p.id == providerId);
    _clearAppDomainAssignmentsMatching(settings, dropped);
    if (settings.providerConfigs.length != lengthBefore) {
      modelsLogger.info(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.info,
          message:
              'deleteProvider: provider=$providerId droppedPresets=${dropped.length}',
        ),
      );
    }
  }

  void deletePreset({required AppSettings settings, required String presetId}) {
    var removed = false;
    for (final profile in settings.providerConfigs) {
      for (final model in profile.models) {
        if (model.presets.any((p) => p.id == presetId)) {
          model.presets.removeWhere((p) => p.id == presetId);
          removed = true;
          break;
        }
      }
      if (removed) break;
    }
    _clearAppDomainAssignmentsMatching(settings, {presetId});
    if (removed) {
      modelsLogger.info(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.info,
          message: 'deletePreset: preset=$presetId',
        ),
      );
    }
  }

  void _clearAppDomainAssignmentsMatching(
    AppSettings settings,
    Set<String> droppedPresetIds,
  ) {
    for (final domain in LlmProviderDomainEnum.values) {
      final currentId = settings.getAppDomainPresetId(domain);
      if (currentId != null && droppedPresetIds.contains(currentId)) {
        settings.setAppDomainPresetId(domain, null);
      }
    }
  }
}
