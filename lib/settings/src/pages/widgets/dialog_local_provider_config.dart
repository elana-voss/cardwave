import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/pages/widgets/dialog_provider_config.dart'
    show DialogProviderAddResult;
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Add / edit dialog for the "Local (OpenAI-compatible)" provider —
/// KoboldCpp, Ollama, LM Studio, llama.cpp server, or any other backend
/// that speaks the OpenAI chat-completions shape.
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

  static const _defaultBaseUrl = 'http://localhost:5001/v1';
  static const _supportedServersHint =
      'KoboldCpp 5001, Ollama 11434, LM Studio 1234, llama.cpp 8080';

  String _serverUnreachableMessage(String url) =>
      'Could not reach $url. Make sure your local server '
      '(KoboldCpp / Ollama / LM Studio / llama.cpp) is running.';

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
  /// and appends `/v1` if missing. The OpenAI-compat endpoints all live
  /// under `/v1`, but users frequently paste just `http://localhost:5001`.
  String _normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
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
      _models = [];
    });

    try {
      final fetched = await context.read<LlmPureHelpers>().fetchModels(
        provider: LLMProviderEnum.localOpenAi,
        apiKey: _apiKeyController!.text,
        baseUrl: url,
      );
      if (_isDisposed) return;
      setState(() {
        _models = fetched;
        if (fetched.isEmpty) {
          _fetchError =
              'Server reachable but returned no models. Load a model in '
              'your local server first.';
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
    return _profile.allPresets.any(
      (p) => activePresetIds.contains(p.id),
    );
  }

  bool get _canSave {
    if (_isFetching) return false;
    if (_models.isEmpty) return false;
    if (_fetchError != null) return false;
    return true;
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
    final updated = LlmProviderConfig(
      id: _profile.id,
      apiKey: _apiKeyController!.text,
      baseUrl: _normalizeUrl(_baseUrlController!.text),
      providerEnum: LLMProviderEnum.localOpenAi,
      // Pass the OLD adopted models in. If a refresh runs below, the
      // refresher reads .models for preset-preservation by id, then
      // replaces the list with the freshly-fetched/enriched set.
      models: _profile.models,
    );

    // _models was pre-populated from widget.profile.models in initState.
    // If it has diverged, the user clicked Connect and got a different
    // list — apply that list to the saved profile, preserving any
    // presets attached to surviving models.
    final oldIds = {for (final m in _profile.models) m.id};
    final newIds = {for (final m in _models) m.id};
    final modelsChanged =
        oldIds.length != newIds.length || !oldIds.containsAll(newIds);

    if (modelsChanged) {
      final settings = context.read<SettingsService>().settings;
      final mgmt = context.read<LlmManagementService>();
      setState(() => _isFetching = true);
      try {
        await mgmt.refreshProviderModels(
          settings: settings,
          profile: updated,
          trigger: ModelRefreshTriggerEnum.manual,
          preFetchedModels: _models,
        );
      } finally {
        if (mounted) setState(() => _isFetching = false);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Delete provider?',
      message:
          'Permanently delete this Local provider and all its presets? '
          'This cannot be undone.',
      confirmText: 'Delete',
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
              child: const Text('Delete'),
            ),
          if (_isEdit && !_isLocked) const SizedBox(width: 24),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
        builder: (context, isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                _isEdit ? 'Edit Local Provider' : 'Add Local Provider',
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
                        labelText: 'Server URL',
                        hintText: 'http://localhost:5001/v1',
                        helperText: _isEdit
                            ? 'Locked. Delete this provider and add a new '
                                  'one to point at a different server.'
                            : _supportedServersHint,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFieldAutotrim(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key (optional)',
                        hintText:
                            "Leave blank — most local servers don't need one",
                      ),
                      obscureText: true,
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isFetching ? null : _connectAndFetch,
                          icon: const Icon(Icons.power_settings_new, size: 18),
                          label: const Text('Connect & Fetch Models'),
                        ),
                        Expanded(
                          child: _LocalProviderStatusLine(
                            isFetching: _isFetching,
                            fetchError: _fetchError,
                            modelCount: _models.length,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocalProviderStatusLine extends StatelessWidget {
  const _LocalProviderStatusLine({
    required this.isFetching,
    required this.fetchError,
    required this.modelCount,
  });
  final bool isFetching;
  final String? fetchError;
  final int modelCount;

  @override
  Widget build(BuildContext context) {
    if (isFetching) {
      return const Row(
        spacing: 8,
        children: [
          SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text('Connecting…', style: TextStyle(fontSize: 12)),
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
    if (modelCount > 0) {
      return Text(
        'Connected. Found $modelCount model${modelCount == 1 ? '' : 's'}.',
        style: TextStyle(color: colorScheme.primary, fontSize: 12),
      );
    }
    return const SizedBox(height: 14);
  }
}
