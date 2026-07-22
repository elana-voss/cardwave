import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Per-model editor for a custom (OpenAI-compatible) provider. Opened from
/// [DialogLocalProviderConfig] as a dialog-from-dialog. Pops the built
/// [LlmModel] on save, null on dismiss.
///
/// A custom model is a plain [LlmModel] the user fills in by hand: the fetch
/// only supplies an id, so context size and the sampling set are unknown
/// until entered here. Only the parameters the shared request path can
/// actually send are offered — temperature, response length, top_p,
/// frequency/presence penalty, and seed. The enabled set becomes
/// `supportedParameters` (the resolver drops anything not listed), and each
/// enabled value becomes the model's default for that parameter.
class DialogLocalModelConfig extends StatefulWidget {
  const DialogLocalModelConfig({super.key, this.model});

  /// The model being edited, or null to add a new one.
  final LlmModel? model;

  @override
  State<DialogLocalModelConfig> createState() => _DialogLocalModelConfigState();
}

/// The sampling parameters a custom model may send, in display order.
/// Context size and response length have their own dedicated fields, so they
/// are not repeated here. top_k / min_p / top_a / repetition penalty are
/// absent because the shared genkit_openai options object can't transmit
/// them.
const _sendableParamIds = [
  LlmParameterDefinitionIdEnum.temperature,
  LlmParameterDefinitionIdEnum.topP,
  LlmParameterDefinitionIdEnum.frequencyPenalty,
  LlmParameterDefinitionIdEnum.presencePenalty,
  LlmParameterDefinitionIdEnum.seed,
];

/// Parameters enabled by default on a fresh model. Response length is always
/// sent (the request path falls back to the model's max-output value), so it
/// isn't a toggle; temperature is the one sampling knob most servers expect.
const _defaultOnParamIds = {LlmParameterDefinitionIdEnum.temperature};

class _DialogLocalModelConfigState extends State<DialogLocalModelConfig> {
  final _formKey = GlobalKey<FormState>();
  final _paramDefs = {for (final p in commonParameters) p.id: p};

  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _contextController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _enabled = <LlmParameterDefinitionIdEnum, bool>{};
  final _valueControllers =
      <LlmParameterDefinitionIdEnum, TextEditingController>{};

  bool get _isEdit => widget.model != null;

  @override
  void initState() {
    super.initState();
    final model = widget.model;
    _nameController.text = model?.name ?? '';
    _idController.text = model?.id ?? '';
    _contextController.text =
        (model?.contextLength ?? LlmConstants.fallbackContextLength).toString();
    _maxTokensController.text =
        (model?.maxOutputTokens ?? LlmConstants.fallbackMaxResponseTokens)
            .toString();
    for (final id in _sendableParamIds) {
      final def = _paramDefs[id]!;
      _enabled[id] = model != null
          ? model.supportedParameters.contains(id)
          : _defaultOnParamIds.contains(id);
      final value = model?.defaultParameters[id] ?? def.defaultValue;
      _valueControllers[id] = TextEditingController(text: _format(def, value));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _contextController.dispose();
    _maxTokensController.dispose();
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _format(LlmParameterDefinition def, double value) =>
      def.type == LlmParameterDefinitionTypeEnum.integer
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    final supported = <LlmParameterDefinitionIdEnum>[
      LlmParameterDefinitionIdEnum.maxResponseLength,
      for (final paramId in _sendableParamIds)
        if (_enabled[paramId] == true) paramId,
    ];
    final defaults = <LlmParameterDefinitionIdEnum, double>{
      for (final paramId in _sendableParamIds)
        if (_enabled[paramId] == true) paramId: _valueOf(paramId),
    };
    // Both fields carry digits only (input formatter) and are gated by an
    // int >= 1 validator that already passed in _save's validate() call, so
    // the parse cannot fail here.
    final built = LlmModel(
      id: id,
      name: name.isEmpty ? id : name,
      contextLength: int.parse(_contextController.text),
      maxOutputTokens: int.parse(_maxTokensController.text),
      supportedParameters: supported,
      defaultParameters: defaults,
      // Carry the old model's presets and unavailable flag across the
      // rebuild — the read-only LlmModel fields force a fresh object, and
      // dropping the presets here would strip the default chat preset seeded
      // at add time and break its domain assignment.
      presets: widget.model?.presets ?? [],
      isUnavailable: widget.model?.isUnavailable ?? false,
    );
    Navigator.pop<LlmModel>(context, built);
  }

  double _valueOf(LlmParameterDefinitionIdEnum id) {
    final def = _paramDefs[id]!;
    final parsed = double.tryParse(_valueControllers[id]!.text);
    return (parsed ?? def.defaultValue).clamp(def.min, def.max);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AppDialog(
      actions: [
        FilledButton(onPressed: _save, child: Text(t.common.actions.save)),
      ],
      builder: (context, isMobile) {
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(
                _isEdit
                    ? t.settings.localProviderConfig.editModelHeader
                    : t.settings.localProviderConfig.addModelHeader,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextFieldAutotrim(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: t.settings.localProviderConfig.modelIdLabel,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? t.settings.presetConfig.requiredValidator
                    : null,
              ),
              TextFieldAutotrim(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: t.settings.localProviderConfig.modelNameLabel,
                ),
              ),
              _IntegerField(
                controller: _contextController,
                label: t.settings.localProviderConfig.modelContextSizeLabel,
              ),
              _IntegerField(
                controller: _maxTokensController,
                label: t.settings.localProviderConfig.modelMaxResponseLabel,
              ),
              const SizedBox(height: 4),
              Text(
                t.settings.localProviderConfig.sendableParamsHeader,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final id in _sendableParamIds)
                _ParamToggleRow(
                  def: _paramDefs[id]!,
                  enabled: _enabled[id] ?? false,
                  controller: _valueControllers[id]!,
                  onToggle: (v) => setState(() => _enabled[id] = v),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One sampling-parameter row: an enable toggle, the parameter's name with a
/// description tooltip, and a bounded value field that greys out when off.
class _ParamToggleRow extends StatelessWidget {
  const _ParamToggleRow({
    required this.def,
    required this.enabled,
    required this.controller,
    required this.onToggle,
  });
  final LlmParameterDefinition def;
  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Switch(value: enabled, onChanged: onToggle),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            spacing: 4,
            children: [
              Flexible(
                child: Text(
                  def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: def.description,
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 88,
          child: _ParamValueField(
            controller: controller,
            def: def,
            enabled: enabled,
          ),
        ),
      ],
    );
  }
}

/// Positive-integer field for context size / max response length.
class _IntegerField extends StatelessWidget {
  const _IntegerField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return TextFieldAutotrim(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        final parsed = int.tryParse(v?.trim() ?? '');
        if (parsed == null || parsed < 1) {
          return t.settings.presetConfig.invalidValidator;
        }
        return null;
      },
    );
  }
}

/// Compact numeric value field for a single sampling parameter, bounded by
/// the parameter's declared min/max. Disabled (and never validated) when its
/// row's toggle is off.
class _ParamValueField extends StatelessWidget {
  const _ParamValueField({
    required this.controller,
    required this.def,
    required this.enabled,
  });
  final TextEditingController controller;
  final LlmParameterDefinition def;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isInteger = def.type == LlmParameterDefinitionTypeEnum.integer;
    final signed = def.min < 0;
    return TextFieldAutotrim(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !isInteger,
        signed: signed,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(
            isInteger
                ? (signed ? r'^-?\d*$' : r'^\d*$')
                : (signed ? r'^-?\d*\.?\d*$' : r'^\d*\.?\d*$'),
          ),
        ),
      ],
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        errorStyle: TextStyle(height: 0),
      ),
      validator: (value) {
        if (!enabled) return null;
        final parsed = double.tryParse(value ?? '');
        if (parsed == null || parsed < def.min || parsed > def.max) {
          return '${def.min} - ${def.max}';
        }
        return null;
      },
    );
  }
}
