import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Result popped by [DialogProviderConfig] in add mode. Carries the newly
/// built empty profile plus the model list the dialog already fetched for
/// its picker — passed to `LlmPureHelpers.refreshProviderModels` so that call
/// doesn't re-hit the provider.
typedef DialogProviderAddResult = ({
  LlmProviderConfig profile,
  List<LlmModel> fetchedModels,
});

class DialogProviderConfig extends StatefulWidget {
  const DialogProviderConfig({super.key, this.profile});
  final LlmProviderConfig? profile;

  @override
  State<DialogProviderConfig> createState() => _DialogProviderConfigState();
}

class _DialogProviderConfigState extends State<DialogProviderConfig> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _apiKeyController;

  bool _isFetching = false;
  String? _fetchError;
  List<LlmModel> _models = [];
  late bool _requireZdr;

  Timer? _fetchDebounce;
  bool _isDisposed = false;
  static const Duration _fetchDebounceDelay = Duration(milliseconds: 500);
  static const int _minKeyLengthForFetch = 20;

  bool get _isEdit => widget.profile != null;

  /// `widget.profile` unwrapped. Only valid when [_isEdit] — every read
  /// below is gated by an `_isEdit` check.
  LlmProviderConfig get _profile => widget.profile!;

  LLMProviderEnum? get _keyOwner =>
      LlmProvider.detectFromApiKey(_apiKeyController!.text);

  LLMProviderEnum? get _detectedProvider =>
      _isEdit ? _profile.providerEnum : _keyOwner;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.profile?.apiKey ?? '',
    );
    _requireZdr = widget.profile?.requireZdr ?? false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fetchDebounce?.cancel();
    _apiKeyController?.dispose();
    super.dispose();
  }

  void _onKeyChanged(String key) {
    setState(() {
      _fetchError = null;
      if (!_isEdit) _models = [];
    });

    if (_isEdit) return;

    _fetchDebounce?.cancel();
    final detected = LlmProvider.detectFromApiKey(key);
    if (detected != null && key.length >= _minKeyLengthForFetch) {
      _fetchDebounce = Timer(_fetchDebounceDelay, _fetchModels);
    }
  }

  Future<void> _fetchModels() async {
    if (_isDisposed || _detectedProvider == null) return;

    setState(() {
      _isFetching = true;
      _fetchError = null;
      _models = [];
    });

    try {
      final fetched = await context.read<LlmPureHelpers>().fetchModels(
        provider: _detectedProvider!,
        apiKey: _apiKeyController!.text,
        requireZdr: _requireZdr,
      );
      if (_isDisposed) return;
      setState(() {
        _models = fetched;
        if (fetched.isEmpty) {
          _fetchError = 'No models returned. Check your API key.';
        }
      });
    } on Exception catch (e, st) {
      LoggingService().error('Provider-config model fetch failed', e, st);
      if (_isDisposed) return;
      setState(
        () => _fetchError =
            'Could not connect. Check your internet connection and API key.',
      );
    } finally {
      if (!_isDisposed) setState(() => _isFetching = false);
    }
  }

  /// Edit-mode cross-provider guard. Presets reference provider-specific
  /// model ids that would be invalidated if the key were swapped to a
  /// different provider.
  bool get _editKeyMismatch =>
      _isEdit &&
      _apiKeyController!.text.isNotEmpty &&
      _keyOwner != _profile.providerEnum;

  bool get _zdrDirty => _isEdit && _requireZdr != _profile.requireZdr;

  /// App-domain roles (Chat, Assistant, Image, …) currently backed by one of
  /// this provider's presets. Non-empty means the provider can't be deleted —
  /// a feature still points at it. Drives both the hidden Delete button and
  /// the reason hint shown in its place.
  List<String> get _lockingRoleLabels {
    if (!_isEdit) return const [];
    final settings = context.read<SettingsService>().settings;
    final presetIds = _profile.allPresets.map((p) => p.id).toSet();
    return [
      for (final domain in LlmProviderDomainEnum.values)
        if (presetIds.contains(settings.getAppDomainPresetId(domain)))
          domain.label,
    ];
  }

  Future<void> _confirmDelete() async {
    final providerLabel = LlmProvider.of(_profile.providerEnum).label;
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Delete provider?',
      message:
          'Permanently delete the $providerLabel provider and all its presets? '
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

  bool get _canSave {
    if (_apiKeyController!.text.isEmpty) return false;
    if (_isEdit) {
      if (_editKeyMismatch) return false;
      // If the ZDR flag changed, we must have refetched the model list
      // successfully — otherwise the profile's persisted models may no
      // longer be valid under the new flag.
      if (_zdrDirty &&
          (_isFetching || _fetchError != null || _models.isEmpty)) {
        return false;
      }
      return true;
    }
    // Add mode needs a recognized key AND a successful fetch.
    return _detectedProvider != null &&
        !_isFetching &&
        _models.isNotEmpty &&
        _fetchError == null;
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    if (!_canSave) return;

    if (_isEdit) {
      _saveEdit();
    } else {
      _saveAdd();
    }
  }

  void _saveEdit() {
    // Preserve everything except the API key. Cross-provider changes are
    // blocked by [_editKeyMismatch] / [_canSave]. When the ZDR flag
    // changed, we keep adopted models (with their presets) that survived
    // the refetched, filtered catalog; the rest are dropped and heal
    // reassigns any orphaned domain presets.
    final models = _zdrDirty
        ? context.read<LlmPureHelpers>().pruneAdoptedToIds(
            _profile.models,
            _models.map((m) => m.id).toSet(),
          )
        : _profile.models;
    final updated = LlmProviderConfig(
      id: _profile.id,
      apiKey: _apiKeyController!.text,
      providerEnum: _profile.providerEnum,
      models: models,
      requireZdr: _requireZdr,
    );
    Navigator.pop(context, updated);
  }

  void _saveAdd() {
    // Add-mode `_save` only reaches here when `_canSave`, which requires
    // `_detectedProvider != null`.
    final detectedProvider = _detectedProvider!;
    final profile = LlmProviderConfig(
      id: UtilsApp.generateId(detectedProvider.name),
      apiKey: _apiKeyController!.text,
      providerEnum: detectedProvider,
      models: [],
      requireZdr: _requireZdr,
    );
    Navigator.pop<DialogProviderAddResult>(context, (
      profile: profile,
      fetchedModels: _models,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lockingRoles = _lockingRoleLabels;
    final isLocked = lockingRoles.isNotEmpty;
    final lockHint = isLocked
        ? 'Cannot delete: in use by ${_joinRoles(lockingRoles)}.'
        : null;
    return AppDialog(
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: isLocked ? null : _confirmDelete,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        if (_isEdit) const SizedBox(width: 24),
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
              _isEdit ? 'Edit Provider' : 'Add Provider',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFieldAutotrim(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: _isEdit
                          ? 'Paste a new key to rotate'
                          : 'Paste your key — provider is auto-detected',
                    ),
                    obscureText: true,
                    onChanged: _onKeyChanged,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  _ProviderStatusLine(
                    isEdit: _isEdit,
                    editKeyMismatch: _editKeyMismatch,
                    isFetching: _isFetching,
                    fetchError: _fetchError,
                    hasModels: _models.isNotEmpty,
                    detectedProvider: _detectedProvider,
                    keyOwner: _keyOwner,
                    profileProviderEnum: _isEdit ? _profile.providerEnum : null,
                    apiKeyText: _apiKeyController!.text,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Supports OpenAI, Anthropic, Google, Grok, OpenRouter, NanoGPT.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (lockHint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      lockHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_detectedProvider == LLMProviderEnum.openrouter)
                    SwitchTileZdr(
                      value: _requireZdr,
                      onChanged: _isFetching ? null : _onZdrChanged,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _onZdrChanged(bool value) {
    if (_requireZdr == value) return;
    setState(() {
      _requireZdr = value;
      _models = [];
      _fetchError = null;
    });
    if (_apiKeyController!.text.isNotEmpty) unawaited(_fetchModels());
  }

}

/// "Chat", "Chat and Assistant", "Chat, Assistant and Image".
String _joinRoles(List<String> roles) => roles.length == 1
    ? roles.first
    : '${roles.sublist(0, roles.length - 1).join(', ')} and ${roles.last}';

class _ProviderStatusLine extends StatelessWidget {
  const _ProviderStatusLine({
    required this.isEdit,
    required this.editKeyMismatch,
    required this.isFetching,
    required this.fetchError,
    required this.hasModels,
    required this.detectedProvider,
    required this.keyOwner,
    required this.profileProviderEnum,
    required this.apiKeyText,
  });
  final bool isEdit;
  final bool editKeyMismatch;
  final bool isFetching;
  final String? fetchError;
  final bool hasModels;
  final LLMProviderEnum? detectedProvider;
  final LLMProviderEnum? keyOwner;
  final LLMProviderEnum? profileProviderEnum;
  final String apiKeyText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isEdit && editKeyMismatch) {
      final owner = keyOwner;
      final ownerLabel = owner != null
          ? LlmProvider.of(owner).label
          : 'another provider';
      final profileLabel = LlmProvider.of(profileProviderEnum!).label;
      return Text(
        'This key belongs to $ownerLabel, but this profile is $profileLabel. '
        'Delete this profile and add a new one instead.',
        style: TextStyle(color: colorScheme.error, fontSize: 12),
      );
    }
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
    if (fetchError != null) {
      return Text(
        fetchError!,
        style: TextStyle(color: colorScheme.error, fontSize: 12),
      );
    }
    if (!isEdit && hasModels && detectedProvider != null) {
      return Text(
        'Connected to ${LlmProvider.of(detectedProvider!).label}. '
        'Default presets will be created.',
        style: TextStyle(color: colorScheme.primary, fontSize: 12),
      );
    }
    if (detectedProvider != null) {
      return Text(
        'Detected: ${LlmProvider.of(detectedProvider!).label}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    if (apiKeyText.isNotEmpty) {
      return const Text(
        'Unrecognized key format.',
        style: TextStyle(color: Colors.orange, fontSize: 12),
      );
    }
    return const SizedBox(height: 14);
  }
}
