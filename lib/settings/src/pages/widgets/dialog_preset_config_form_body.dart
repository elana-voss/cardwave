part of 'dialog_preset_config.dart';

class _DialogFormBody extends StatelessWidget {
  const _DialogFormBody({
    required this.formKey,
    required this.nameController,
    required this.nameFocusNode,
    required this.modelTextController,
    required this.onShowModelSelectionDialog,
    required this.activeParameters,
    required this.parameterControllers,
    required this.isMobile,
    required this.selectedModel,
    this.activeDomains = const {},
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final TextEditingController modelTextController;
  final VoidCallback onShowModelSelectionDialog;
  final List<LlmParameterDefinition> activeParameters;
  final Map<LlmParameterDefinitionIdEnum, TextEditingController>
  parameterControllers;
  final bool isMobile;
  final Set<LlmProviderDomainEnum> activeDomains;
  final LlmModel? selectedModel;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = isMobile ? 1 : 2;
          final itemWidth =
              (constraints.maxWidth - (crossAxisCount - 1) * 24) /
              crossAxisCount;

          final nameField = ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameController,
            builder: (context, value, _) {
              return TextFieldAutotrim(
                controller: nameController,
                focusNode: nameFocusNode,
                decoration: InputDecoration(
                  labelText: 'Model name',
                  errorStyle: const TextStyle(height: 0),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear',
                          onPressed: () {
                            nameController.clear();
                            nameFocusNode.requestFocus();
                          },
                        ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              );
            },
          );

          final modelField = TextFieldAutotrim(
            controller: modelTextController,
            readOnly: true,
            style: const TextStyle(overflow: TextOverflow.ellipsis),
            decoration: const InputDecoration(
              labelText: 'Model',
              errorStyle: TextStyle(height: 0),
              suffixIcon: Icon(Icons.arrow_drop_down),
              hintText: 'Select a model',
            ),
            onTap: onShowModelSelectionDialog,
            validator: (value) =>
                value == null || value.isEmpty ? 'Model is required' : null,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeDomains.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          'Models are filtered to support the active domains: ${activeDomains.map((d) => d.label).join(', ')}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isMobile) ...[
                nameField,
                const SizedBox(height: 16),
                modelField,
              ] else
                Row(
                  spacing: 16,
                  children: [
                    Expanded(child: nameField),
                    Expanded(child: modelField),
                  ],
                ),
              if (selectedModel != null)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: TileModel(model: selectedModel!),
                ),
              Wrap(
                spacing: 24,
                children: [
                  for (final param in activeParameters)
                    SizedBox(
                      width: itemWidth,
                      child: DialogPresetConfigParameterInputWidget(
                        key: ValueKey(param.id),
                        parameter: param,
                        controller: parameterControllers[param.id]!,
                        isMobile: isMobile,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
