import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/widgets/app_search_field.dart';
import 'package:cardwave/common/src/widgets/tile_model.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

class DialogModelSelection extends StatefulWidget {
  const DialogModelSelection({
    required this.models,
    required this.provider,
    super.key,
  });
  final List<LlmModel> models;
  final LLMProviderEnum provider;

  @override
  State<DialogModelSelection> createState() => DialogModelSelectionState();
}

class DialogModelSelectionState extends State<DialogModelSelection> {
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlySubscriptionModels = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filteredModels = widget.models.where((m) {
      if (_showOnlySubscriptionModels && m.subscription?.included != true) {
        return false;
      }
      if (query.isEmpty) return true;
      return m.id.toLowerCase().contains(query) ||
          m.name.toLowerCase().contains(query);
    }).toList();

    return AppDialog(
      isScrollable: false,
      builder: (context, isMobile) {
        return Column(
          children: [
            AppSearchField(
              controller: _searchController,
              hintText: 'Search Models',
              autofocus: true,
            ),
            if (widget.provider == LLMProviderEnum.nanogpt) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(
                  'Show only subscription models (${widget.models.where((m) => m.subscription?.included == true).length}/${widget.models.length})',
                ),
                contentPadding: EdgeInsets.zero,
                value: _showOnlySubscriptionModels,
                onChanged: (val) =>
                    setState(() => _showOnlySubscriptionModels = val),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filteredModels.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final model = filteredModels[index];
                  return TileModel(
                    model: model,
                    onTap: () => Navigator.pop(context, model.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
