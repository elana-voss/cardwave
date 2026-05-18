class SelectionOption<T> {
  const SelectionOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
  final T value;
  final String label;
  final String? subtitle;
}
