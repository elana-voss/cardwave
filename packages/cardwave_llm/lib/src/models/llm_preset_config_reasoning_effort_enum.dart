// Budget values are a first-cut ladder — tune after real usage.
enum LlmPresetConfigReasoningEffortEnum {
  off(label: 'Off', budgetTokens: 0),
  low(label: 'Low', budgetTokens: 2000),
  medium(label: 'Medium', budgetTokens: 8000),
  high(label: 'High', budgetTokens: 16000)
  ;

  final String label;
  final int budgetTokens;

  const LlmPresetConfigReasoningEffortEnum({
    required this.label,
    required this.budgetTokens,
  });

  bool get isOn => this != LlmPresetConfigReasoningEffortEnum.off;
}
