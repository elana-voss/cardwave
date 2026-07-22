import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/pages/widgets/dialog_local_model_config.dart';
import 'package:cardwave/settings/src/pages/widgets/dialog_provider_config.dart'
    show DialogProviderAddResult;
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Add / edit dialog for the "Custom (OpenAI-compatible)" provider —
/// KoboldCpp, Ollama, LM Studio, llama.cpp server, or any other local or
/// remote backend that speaks the OpenAI chat-completions shape.
///
/// Kept separate from [DialogProviderConfig] (the cloud dialog) because
/// the flows are fundamentally different: cloud auto-detects the provider
/// from a pasted key prefix and debounces a fetch; local has no key to
/// detect from, so the user types a `baseUrl` and clicks Connect. Sharing
/// a single widget would scatter `if (localMode)` branches across the
/// cloud path.
///
/// On add success, pops a [DialogProviderAddResult] (same record type as
/// the cloud dialog). On edit save, pops the updated [LlmProviderConfig].
class DialogLocalProviderConfig extends StatefulWidget {
  const DialogLocalProviderConfig({super.key, this.profile});
  final LlmProviderConfig? profile;

  @override
  State<DialogLocalProviderConfig> createState() =>
      _DialogLocalProviderConfigState();
}

class _DialogLocalProviderConfigState extends State<DialogLocalProviderConfig> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _apiKeyController;
  TextEditingController? _baseUrlController;

  bool _isFetching = false;
  String? _fetchError;
  List<LlmModel> _models = [];
  bool _isDisposed = false;
  // True once a server fetch has succeeded this session. Gates the
  // "Connected. Found N" status so a hand-added-only list (or an edit dialog
  // that pre-populated its models without connecting) doesn't falsely claim
  // a connection happened.
  bool _didFetch = false;

  static const _defaultBaseUrl = 'http://localhost:5001/v1';
  static const _supportedServersHint =
      'KoboldCpp 5001, Ollama 11434, LM Studio 1234, llama.cpp 8080, '
      'or any remote OpenAI-compatible URL';

  String _serverUnreachableMessage(String url) =>
      t.settings.localProviderConfig.serverUnreachableMessage(url: url);

  bool get _isEdit => widget.profile != null;

  /// `widget.profile` unwrapped. Only valid when [_isEdit] / `widget.profile
  /// != null` — every read below is gated by such a check.
  LlmProviderConfig get _profile => widget.profile!;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.profile?.apiKey ?? '',
    );
    _baseUrlController = TextEditingController(
      text: widget.profile?.baseUrl ?? _defaultBaseUrl,
    );
    // Edit mode pre-populates _models from the saved profile so Save is
    // immediately enabled — the user shouldn't have to re-fetch just to
    // tweak the (optional) API key. They can still hit Connect to verify.
    if (widget.profile != null) {
      _models = List.of(_profile.models);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _apiKeyController?.dispose();
    _baseUrlController?.dispose();
    super.dispose();
  }

  /// Normalizes a user-typed URL: trims whitespace, strips a trailing slash,
  /// drops a pasted endpoint path (`/models`, `/chat/completions`,
  /// `/completions`), and appends `/v1` if missing. The OpenAI-compat
  /// endpoints all live under `/v1`, but users frequently paste just
  /// `http://localhost:5001` — or a full endpoint URL copied from provider
  /// docs, like `https://api.example.com/v1/chat/completions`.
  String _normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    for (final endpointPath in [
      '/chat/completions',
      '/completions',
      '/models',
    ]) {
      if (url.endsWith(endpointPath)) {
        url = url.substring(0, url.length - endpointPath.length);
        break;
      }
    }
    if (!url.endsWith('/v1')) url = '$url/v1';
    return url;
  }

  Future<void> _connectAndFetch() async {
    final url = _normalizeUrl(_baseUrlController!.text);
    if (url.isEmpty) return;
    // Push the normalized form back into the field so the user sees what
    // we'll persist.
    _baseUrlController!.text = url;

    setState(() {
      _isFetching = true;
      _fetchError = null;
    });

    try {
      final fetched = await context.read<LlmPureHelpers>().fetchModels(
        provider: LLMProviderEnum.localOpenAi,
        apiKey: _apiKeyController!.text,
        baseUrl: url,
      );
      if (_isDisposed) return;
      setState(() {
        _didFetch = true;
        // Merge, don't replace: hand-added models, per-model edits, and (in
        // edit mode) the existing models that carry the user's presets and
        // context sizes must survive a Connect. Only fetched ids not already
        // present join, as blank templates. Wiping _models here would destroy
        // that hand-entered state on every fetch — and on a failed fetch too.
        final existingIds = {for (final m in _models) m.id};
        _models = [
          ..._models,
          for (final m in fetched)
            if (!existingIds.contains(m.id)) m,
        ];
        if (fetched.isEmpty) {
          _fetchError = t.settings.localProviderConfig.noModelsError;
        }
      });
    } on LlmFetchException catch (e) {
      // statusCode == null means transport failure (server unreachable) —
      // show the friendly "is the server running?" hint. Any non-null
      // status means the server replied with an error (wrong endpoint,
      // bad key, model not loaded, etc.); surface its parsed message so
      // the user troubleshoots the right thing.
      if (_isDisposed) return;
      setState(() {
        _fetchError = e.statusCode == null
            ? _serverUnreachableMessage(url)
            : e.userMessage;
      });
    } on Exception {
      if (_isDisposed) return;
      setState(() {
        _fetchError = _serverUnreachableMessage(url);
      });
    } finally {
      if (!_isDisposed) setState(() => _isFetching = false);
    }
  }

  bool get _isLocked {
    if (!_isEdit) return false;
    final activePresetIds = context
        .read<SettingsService>()
        .settings
        .activeAppDomainPresetIds;
    return _profile.allPresets.any((p) => activePresetIds.contains(p.id));
  }

  // Save needs at least one model, but no longer a *fetched* one — a
  // hand-added list satisfies it. A live fetch error no longer blocks Save:
  // a failed Connect leaves _models empty (so Save stays off), but once the
  // user adds a model by hand the stale error must not keep gating them.
  bool get _canSave => !_isFetching && _models.isNotEmpty;

  Future<void> _addModelByHand() async {
    final model = await showDialog<LlmModel>(
      context: context,
      builder: (_) => const DialogLocalModelConfig(),
    );
    if (model == null || !mounted) return;
    setState(() {
      _models = [..._models, model];
      _fetchError = null;
    });
  }

  Future<void> _editModel(int index) async {
    // `index` is supplied by the model list's bounded for-loop, so it is
    // always within range.
    // ignore: qcheck/avoid_unsafe_collection_methods
    final existing = _models[index];
    final model = await showDialog<LlmModel>(
      context: context,
      builder: (_) => DialogLocalModelConfig(model: existing),
    );
    if (model == null || !mounted) return;
    setState(() {
      final next = List.of(_models);
      next[index] = model;
      _models = next;
    });
  }

  void _removeModel(int index) {
    setState(() {
      final next = List.of(_models)..removeAt(index);
      _models = next;
    });
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    if (!_canSave) return;
    if (_isEdit) {
      unawaited(_saveEdit());
    } else {
      _saveAdd();
    }
  }

  void _saveAdd() {
    final profile = LlmProviderConfig(
      id: UtilsApp.generateId(LLMProviderEnum.localOpenAi.name),
      apiKey: _apiKeyController!.text,
      baseUrl: _normalizeUrl(_baseUrlController!.text),
      providerEnum: LLMProviderEnum.localOpenAi,
      models: [],
    );
    Navigator.pop<DialogProviderAddResult>(context, (
      profile: profile,
      fetchedModels: _models,
    ));
  }

  Future<void> _saveEdit() async {
    // The dialog's model list is authoritative — it already reflects every
    // hand-add, per-model edit, remove, and Connect result, each carrying
    // its own presets. The custom-provider refresh is add-only, so it can't
    // drop or overwrite these; it only seeds a default chat preset if the
    // profile has none yet and enriches option rosters (a no-op for a
    // chat-only local backend).
    final updated = LlmProviderConfig(
      id: _profile.id,
      apiKey: _apiKeyController!.text,
      baseUrl: _normalizeUrl(_baseUrlController!.text),
      providerEnum: LLMProviderEnum.localOpenAi,
      models: List.of(_models),
    );

    final settings = context.read<SettingsService>().settings;
    final mgmt = context.read<LlmManagementService>();
    setState(() => _isFetching = true);
    try {
      await mgmt.refreshProviderModels(
        settings: settings,
        profile: updated,
        trigger: ModelRefreshTriggerEnum.manual,
        preFetchedModels: updated.models,
      );
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: t.settings.providerConfig.deleteProviderTitle,
      message: t.settings.localProviderConfig.deleteProviderMessage,
      confirmText: t.common.actions.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!confirmed || !mounted) return;

    final settingsService = context.read<SettingsService>();
    context.read<LlmManagementService>().deleteProvider(
      settings: settingsService.settings,
      providerId: _profile.id,
    );
    await settingsService.saveSettings();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    // While a fetch is in flight, block accidental dismissal (back
    // button via PopScope) and disable Delete (destructive — the user
    // should explicitly cancel the current action first). Cancel stays
    // enabled because it's the user's intentional escape hatch if the
    // fetch hangs; popping mid-await safely orphans the operation
    // (mounted guards skip the post-await setState / Navigator.pop).
    return PopScope(
      canPop: !_isFetching,
      child: AppDialog(
        actions: [
          if (_isEdit && !_isLocked)
            TextButton(
              onPressed: _isFetching ? null : _confirmDelete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(t.common.actions.delete),
            ),
          if (_isEdit && !_isLocked) const SizedBox(width: 24),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: Text(t.common.actions.save),
          ),
        ],
        builder: (context, isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                _isEdit
                    ? t.settings.localProviderConfig.editHeader
                    : t.settings.localProviderConfig.addHeader,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    TextFormField(
                      // Key carried only to give integration tests an
                      // unambiguous handle — `find.byType(TextFormField)`
                      // matches both Server URL and the API Key field
                      // (TextFieldAutotrim wraps TextFormField), and
                      // tree-order resolution has flaked in real-backend
                      // runs. `test`-prefixed so it reads as test-only.
                      key: const Key('testServerUrlField'),
                      controller: _baseUrlController,
                      enabled: !_isEdit,
                      decoration: InputDecoration(
                        labelText:
                            t.settings.localProviderConfig.serverUrlLabel,
                        hintText: 'http://localhost:5001/v1',
                        helperText: _isEdit
                            ? t
                                  .settings
                                  .localProviderConfig
                                  .serverUrlLockedHelper
                            : _supportedServersHint,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? t.settings.presetConfig.requiredValidator
                          : null,
                    ),
                    TextFieldAutotrim(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText:
                            t.settings.localProviderConfig.apiKeyOptionalLabel,
                        hintText:
                            t.settings.localProviderConfig.apiKeyOptionalHint,
                      ),
                      obscureText: true,
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isFetching ? null : _connectAndFetch,
                          icon: const Icon(Icons.power_settings_new, size: 18),
                          label: Text(
                            t.settings.localProviderConfig.connectFetchButton,
                          ),
                        ),
                        Expanded(
                          child: _LocalProviderStatusLine(
                            isFetching: _isFetching,
                            fetchError: _fetchError,
                            didFetch: _didFetch,
                            modelCount: _models.length,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _LocalProviderModelList(
                models: _models,
                activePresetIds: context
                    .read<SettingsService>()
                    .settings
                    .activeAppDomainPresetIds,
                onEdit: _editModel,
                onRemove: _removeModel,
                onAddByHand: _addModelByHand,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The editable roster below the Connect row: one tappable tile per model
/// (tap to edit, trash to remove) plus the "add by hand" action. Empty until
/// the user connects to a server or adds a model by hand.
class _LocalProviderModelList extends StatelessWidget {
  const _LocalProviderModelList({
    required this.models,
    required this.activePresetIds,
    required this.onEdit,
    required this.onRemove,
    required this.onAddByHand,
  });
  final List<LlmModel> models;

  /// Preset ids currently assigned to a domain. A model holding one of these
  /// backs a live chat/system/etc. slot, so its remove control is hidden —
  /// the user unassigns the domain first, exactly as the whole-provider
  /// Delete and the per-preset Delete already behave.
  final Set<String> activePresetIds;
  final void Function(int index) onEdit;
  final void Function(int index) onRemove;
  final VoidCallback onAddByHand;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (models.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              t.settings.localProviderConfig.noModelsYet,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          )
        else
          for (var i = 0; i < models.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(models[i].name),
              subtitle: models[i].name != models[i].id
                  ? Text(models[i].id)
                  : null,
              onTap: () => onEdit(i),
              trailing:
                  models[i].presets.any((p) => activePresetIds.contains(p.id))
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip:
                          t.settings.localProviderConfig.removeModelTooltip,
                      onPressed: () => onRemove(i),
                    ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddByHand,
            icon: const Icon(Icons.add, size: 18),
            label: Text(t.settings.localProviderConfig.addModelByHandButton),
          ),
        ),
      ],
    );
  }
}

class _LocalProviderStatusLine extends StatelessWidget {
  const _LocalProviderStatusLine({
    required this.isFetching,
    required this.fetchError,
    required this.didFetch,
    required this.modelCount,
  });
  final bool isFetching;
  final String? fetchError;
  final bool didFetch;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    if (isFetching) {
      return Row(
        spacing: 8,
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text(
            t.settings.providerConfig.connectingStatus,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    if (fetchError != null) {
      return Text(
        fetchError!,
        style: TextStyle(color: colorScheme.error, fontSize: 12),
      );
    }
    if (didFetch && modelCount > 0) {
      return Text(
        t.settings.localProviderConfig.connectedFoundModels(n: modelCount),
        style: TextStyle(color: colorScheme.primary, fontSize: 12),
      );
    }
    return const SizedBox(height: 14);
  }
}
