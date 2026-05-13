part of 'dialog_preset_config.dart';

class ParameterInputWidget extends StatefulWidget {
  const ParameterInputWidget({
    required this.parameter,
    required this.controller,
    required this.isMobile,
    super.key,
  });
  final LlmParameterDefinition parameter;
  final TextEditingController controller;
  final bool isMobile;

  @override
  State<ParameterInputWidget> createState() => _ParameterInputWidgetState();
}
