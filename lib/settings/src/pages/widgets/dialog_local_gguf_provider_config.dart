import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/controllers/local_gguf_dialog_controller.dart';
import 'package:cardwave/settings/src/utils/local_gguf_strings.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Add dialog for an in-process GGUF chat provider. Picks a `.gguf` file,
/// probes its metadata and the GPU's free VRAM, proposes a fitting
/// `(contextSize, kvCacheType)` pair (user-editable), and verifies the load
/// before persistence. On Save, pops the constructed [LlmProviderConfig].
class DialogLocalGgufProviderConfig extends StatefulWidget {
  const DialogLocalGgufProviderConfig({super.key});

  @override
  State<DialogLocalGgufProviderConfig> createState() =>
      _DialogLocalGgufProviderConfigState();
}

class _DialogLocalGgufProviderConfigState
    extends State<DialogLocalGgufProviderConfig> {
  LocalGgufDialogController? _controller;
  final _ctxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = LocalGgufDialogController(embedder: context.read<Embedder>());
    _controller!.addListener(_syncCtxField);
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncCtxField);
    _controller?.dispose();
    _ctxController.dispose();
    super.dispose();
  }

  /// Mirrors the controller's `contextSize` into the text-field whenever the
  /// controller updates from a probe / recommendation change.
  void _syncCtxField() {
    final ctx = _controller!.contextSize;
    if (ctx == null) return;
    final asText = ctx.toString();
    if (_ctxController.text != asText) {
      _ctxController.text = asText;
    }
  }

  void _onCtxSubmitted(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed != null && parsed > 0) {
      _controller!.setContextSize(parsed);
    }
  }

  /// Combined Load + Save: warms the model into VRAM (or surfaces an error),
  /// then on success builds the profile and pops the dialog. One click —
  /// the prior two-button (Load model, Save) flow asked the user to confirm
  /// twice for a single intent.
  Future<void> _loadAndSave() async {
    await _controller!.loadModel();
    if (!_controller!.isModelLoaded || !mounted) return;
    final profile = _controller!.buildProfile();
    if (profile == null) return;
    _controller!.markSaved();
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller!,
      builder: (context, _) {
        final c = _controller!;
        return PopScope(
            canPop: !c.isProbing && !c.isLoadingModel,
            child: AppDialog(
              actions: c.metadata != null
                  ? [
                      FilledButton.icon(
                        icon: c.isLoadingModel
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.memory),
                        label: const Text(kLoadModelLabel),
                        onPressed: (c.canLoadModel && !c.isLoadingModel)
                            ? _loadAndSave
                            : null,
                      ),
                    ]
                  : null,
              builder: (context, isMobile) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: Text(
                        c.pickedPath == null
                            ? kPickFileLabel
                            : _shortenPath(c.pickedPath!),
                      ),
                      onPressed: (c.isProbing || c.isLoadingModel)
                          ? null
                          : c.pickFile,
                    ),
                  ),
                  if (c.isProbing) ...[
                    const SizedBox(height: 12),
                    const Row(
                      spacing: 12,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        Text('Reading model metadata…'),
                      ],
                    ),
                  ],
                  if (c.metadata != null) ...[
                    const SizedBox(height: 16),
                    _InfoRow(
                      label: 'Architecture',
                      value: c.metadata!.architecture,
                    ),
                    _InfoRow(
                      label: kNativeContextLabel,
                      value: c.metadata!.nativeContext.toString(),
                    ),
                    if (c.vram != null)
                      _InfoRow(
                        label: kFreeVramLabel,
                        value: _formatVram(c.vram!),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ctxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: kContextSizeLabel,
                        border: const OutlineInputBorder(),
                        helperText: _maxCtxHint(c),
                        errorText: _ctxExceedsMax(c),
                      ),
                      onSubmitted: _onCtxSubmitted,
                    ),
                    const SizedBox(height: 12),
                    _KvCachePicker(
                      value: c.kvCacheType,
                      onChanged: c.setKvCacheType,
                    ),
                  ],
                  if (c.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      c.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  // The dialog shell zeroes the body's bottom padding when an
                  // action row is present; restore a gap so content doesn't
                  // sit flush against the divider above Close / Load model.
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
    );
  }

  String _shortenPath(String path) {
    const maxLen = 60;
    if (path.length <= maxLen) return path;
    return '…${path.substring(path.length - maxLen + 1)}';
  }

  /// Helper-text under the context field: how many tokens will still
  /// fit in VRAM at the effective KV cache pick. When the picker is on
  /// Auto, the effective pick is the highest-quality KV that fits the
  /// current ctx, so the hint says "auto: <picked> (max N)". When the
  /// user has chosen explicitly, says "max N at <kv> KV". Hidden when
  /// VRAM detection failed (max == 0) or ctx already exceeds max
  /// (errorText takes over).
  String? _maxCtxHint(LocalGgufDialogController c) {
    final max = c.maxContextAtCurrentKv;
    if (max == null || max == 0) return null;
    if (c.contextSize != null && c.contextSize! > max) return null;
    final picked = c.effectiveKvCacheType.name;
    final isAuto = c.kvCacheType == null;
    return isAuto ? 'auto: $picked (max $max)' : 'max $max at $picked KV';
  }

  /// Error-text when the user's ctx exceeds the budget at every KV
  /// option (Auto already picked the loosest — q4_0 — and that still
  /// isn't enough). Renders the TextField in error state.
  String? _ctxExceedsMax(LocalGgufDialogController c) {
    final max = c.maxContextAtCurrentKv;
    final ctx = c.contextSize;
    if (max == null || max == 0 || ctx == null || ctx <= max) return null;
    final picked = c.effectiveKvCacheType.name;
    return 'over $max at $picked KV — load may OOM';
  }

  String _formatVram(({int totalBytes, int freeBytes}) vram) {
    final freeMb = vram.freeBytes ~/ (1024 * 1024);
    final totalMb = vram.totalBytes ~/ (1024 * 1024);
    if (totalMb == 0) return 'not detected';
    return '$freeMb MB / $totalMb MB';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: style?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

class _KvCachePicker extends StatelessWidget {
  const _KvCachePicker({required this.value, required this.onChanged});
  final KvCacheType? value;
  final ValueChanged<KvCacheType?> onChanged;

  @override
  Widget build(BuildContext context) {
    // ValueKey forces a new FormField each time the recommendation algorithm
    // changes the selected value — `initialValue` is read once per widget
    // instance, so without the key the dropdown would stay on its first value.
    return DropdownButtonFormField<KvCacheType?>(
      key: ValueKey(value),
      initialValue: value,
      decoration: const InputDecoration(
        labelText: kKvCacheLabel,
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem<KvCacheType?>(
          value: null,
          child: Text(kKvCacheAutoLabel),
        ),
        DropdownMenuItem(value: KvCacheType.f16, child: Text('fp16')),
        DropdownMenuItem(value: KvCacheType.q8_0, child: Text('q8_0')),
        DropdownMenuItem(value: KvCacheType.q4_0, child: Text('q4_0')),
      ],
      onChanged: onChanged,
    );
  }
}
