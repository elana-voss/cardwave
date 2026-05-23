import 'package:flutter/material.dart';

class DropdownLabeled<T> extends StatelessWidget {
  const DropdownLabeled({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
