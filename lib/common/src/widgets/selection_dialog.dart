import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/widgets/selection_option.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Above this many options the dialog grows a search field. Below it
/// the static list reads faster than a search box would.
const int _searchThreshold = 8;

/// Shows a radio-list picker: an `AppDialog` with one `ListTile` per
/// option, a radio indicator for the active one, and a close button.
/// Auto-grows a search field when [options] exceeds [_searchThreshold].
/// Search matches against label and subtitle, case-insensitive.
///
/// [T] is the value type returned on selection — usually `String` for
/// id-keyed rosters or `int` for discrete numeric choices. [activeValue]
/// must use `==` against items' `SelectionOption.value`, so prefer
/// primitive / value-equal types. Resolves to the picked value or null
/// if the user dismissed without selecting.
Future<T?> showSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<SelectionOption<T>> options,
  required T activeValue,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => _SelectionDialogBody<T>(
      title: title,
      options: options,
      activeValue: activeValue,
    ),
  );
}

class _SelectionDialogBody<T> extends StatefulWidget {
  const _SelectionDialogBody({
    required this.title,
    required this.options,
    required this.activeValue,
  });

  final String title;
  final List<SelectionOption<T>> options;
  final T activeValue;

  @override
  State<_SelectionDialogBody<T>> createState() =>
      _SelectionDialogBodyState<T>();
}

class _SelectionDialogBodyState<T> extends State<_SelectionDialogBody<T>> {
  String _query = '';
  late final bool _showSearch = widget.options.length > _searchThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.options
        : widget.options.where((o) {
            return o.label.toLowerCase().contains(query) ||
                (o.subtitle?.toLowerCase().contains(query) ?? false);
          }).toList();
    Widget buildOption(SelectionOption<T> option) => ListTile(
      leading: Icon(
        option.value == widget.activeValue
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
      ),
      title: Text(option.label),
      subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
      onTap: () => Navigator.pop(context, option.value),
    );

    return AppDialog(
      // When search is shown, pin search at top and scroll the list inside
      // a bounded area so the dialog doesn't shrink/jump as results filter.
      isScrollable: !_showSearch,
      builder: (_, _) {
        final titleWidget = Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(widget.title, style: theme.textTheme.titleLarge),
        );
        if (!_showSearch) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              for (final option in filtered) buildOption(option),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleWidget,
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t.common.selectionDialog.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => buildOption(filtered[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}
