import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/domain_pill.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

part 'dialog_preset_picker_row.dart';

/// Above this many presets the picker grows a search field. Preset rows
/// are taller than `SelectionOption` rows (provider + model + meta line),
/// so the threshold is lower than [showSelectionDialog]'s.
const int _searchThreshold = 6;

class DialogPresetPicker {
  static Future<String?> show({
    required BuildContext context,
    required Widget title,
    required List<
      ({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})
    >
    validPresets,
    String? activePresetId,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _PresetPickerBody(
        title: title,
        validPresets: validPresets,
        activePresetId: activePresetId,
      ),
    );
  }
}

class _PresetPickerBody extends StatefulWidget {
  const _PresetPickerBody({
    required this.title,
    required this.validPresets,
    required this.activePresetId,
  });

  final Widget title;
  final List<
    ({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})
  >
  validPresets;
  final String? activePresetId;

  @override
  State<_PresetPickerBody> createState() => _PresetPickerBodyState();
}

class _PresetPickerBodyState extends State<_PresetPickerBody> {
  String _query = '';
  late final bool _showSearch =
      widget.validPresets.length > _searchThreshold;
  late final Map<String, List<LlmProviderDomainEnum>> _domainsByPresetId =
      _computeDomainsByPresetId();

  Map<String, List<LlmProviderDomainEnum>> _computeDomainsByPresetId() {
    final settings = context.read<SettingsService>().settings;
    final result = <String, List<LlmProviderDomainEnum>>{};
    for (final domain in LlmProviderDomainEnum.values) {
      final id = settings.getAppDomainPresetId(domain);
      if (id == null || id.isEmpty) continue;
      result.putIfAbsent(id, () => []).add(domain);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.validPresets
        : widget.validPresets.where((entry) {
            return entry.profile.providerEnum.name
                    .toLowerCase()
                    .contains(query) ||
                entry.model.name.toLowerCase().contains(query) ||
                entry.config.name.toLowerCase().contains(query);
          }).toList();

    // Group by provider in first-appearance order, then build a flat list of
    // widgets: a section header above each provider's run, followed by its
    // preset rows. Same flat list feeds both the short-list Column and the
    // long-list ListView so the two render identically.
    final groups = <LLMProviderEnum, List<
      ({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})
    >>{};
    for (final entry in filtered) {
      groups.putIfAbsent(entry.profile.providerEnum, () => []).add(entry);
    }
    final rowWidgets = <Widget>[];
    for (final group in groups.entries) {
      rowWidgets.add(DrawerSectionHeader(group.key.name.toUpperCase()));
      for (final entry in group.value) {
        rowWidgets.add(
          _PresetRow(
            preset: entry.config,
            model: entry.model,
            activeDomains: _domainsByPresetId[entry.config.id] ?? const [],
            selected: entry.config.id == widget.activePresetId,
            onTap: () => Navigator.pop(context, entry.config.id),
          ),
        );
      }
    }

    return AppDialog(
      // When search is shown, pin search at top and scroll the list inside
      // a bounded area so the dialog doesn't shrink/jump as results filter.
      isScrollable: !_showSearch,
      builder: (ctx, _) {
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.title,
            ),
            const Divider(height: 1, thickness: 0.5),
          ],
        );
        if (!_showSearch) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleWidget, ...rowWidgets],
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
                decoration: const InputDecoration(
                  hintText: 'Search by provider, model, or preset…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rowWidgets.length,
                itemBuilder: (_, i) => rowWidgets[i],
              ),
            ),
          ],
        );
      },
    );
  }
}
