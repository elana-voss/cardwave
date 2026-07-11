import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Compact rounded search field with a leading magnifying-glass icon and a
/// trailing clear button that appears only when there is text. Used by the
/// grid filter row and any picker dialog that lists searchable items.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    super.key,
    this.hintText,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// Placeholder shown when empty. Null falls back to the localized default.
  final String? hintText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hintText ?? t.common.appSearchField.hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            prefixIcon: const Icon(Icons.search, size: 18),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: controller.clear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  )
                : const SizedBox.square(dimension: 32),
          ),
        );
      },
    );
  }
}
