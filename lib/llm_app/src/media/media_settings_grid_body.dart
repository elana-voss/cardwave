import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/src/media/media_resolver.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_dense_section.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_dropdown_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_header.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_preset_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_text_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_tristate_row.dart';
import 'package:cardwave/llm_app/src/models/config_media.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One resolveMedia output per column, each computed with progressively
/// narrower inputs so cells render the value their own layer would
/// resolve to in isolation.
typedef _ResolvedViews = ({
  ConfigMediaResolved app,
  ConfigMediaResolved character,
  ConfigMediaResolved session,
});

/// Renders the multi-layer media-settings grid — section header bands,
/// the 3-column grid, the prompt-prefix section. Designed to embed
/// inside a tabbed dialog ([DialogAiSettings] is the live host); no
/// Scaffold or AppBar of its own.
///
/// Every entry point renders the full App / Character / Current chat
/// triple, so the column set never changes between dialogs. Columns whose
/// scope the entry point didn't supply (no character, no chat session)
/// render "—" cells — the row widgets fall back to a not-applicable cell.
/// [MediaSettingsGridFocus] no longer gates which columns appear; it only
/// picks which column the narrow-layout switcher opens on.
class MediaSettingsGridBody extends StatefulWidget {
  const MediaSettingsGridBody({
    required this.focus,
    required this.chatSession,
    required this.character,
    required this.chatPageController,
    super.key,
  });

  final MediaSettingsGridFocus focus;
  final ChatSession? chatSession;
  final CharacterFile? character;
  final ChatPageController? chatPageController;

  @override
  State<MediaSettingsGridBody> createState() => _MediaSettingsGridBodyState();
}

class _MediaSettingsGridBodyState extends State<MediaSettingsGridBody> {
  // All three layers always render so the column set is identical across
  // every entry point. Columns the entry point didn't scope (null
  // character / null session) show "—" via the row widgets. Wide layouts
  // show them side by side; the narrow switcher cycles all three.
  final List<MediaSettingsGridLayer> _availableLayers = const [
    MediaSettingsGridLayer.app,
    MediaSettingsGridLayer.character,
    MediaSettingsGridLayer.session,
  ];
  late int _currentIndex = _resolveInitialIndex();

  // Stateless helper provided once at app scope — grab it here rather
  // than re-reading it from `context` on every build.
  late final LlmPureHelpers _pureHelpers;

  @override
  void initState() {
    super.initState();
    _pureHelpers = context.read<LlmPureHelpers>();
  }

  /// In narrow mode the switcher opens on the entry-point default
  /// (session for chat-drawer, character for editor-drawer, app for
  /// gear). Every layer is always present, so the lookup always hits.
  int _resolveInitialIndex() {
    final entryDefault = switch (widget.focus) {
      MediaSettingsGridFocus.appOnly => MediaSettingsGridLayer.app,
      MediaSettingsGridFocus.appAndCharacter =>
        MediaSettingsGridLayer.character,
      MediaSettingsGridFocus.allColumns ||
      MediaSettingsGridFocus.sessionOnly => MediaSettingsGridLayer.session,
    };
    return _availableLayers.indexOf(entryDefault);
  }

  // `_availableLayers` is never empty and `_currentIndex` is kept within
  // bounds by `_resolveInitialIndex` and the modular `_cyclePrev`/`_cycleNext`.
  // ignore: qcheck/avoid_unsafe_collection_methods
  MediaSettingsGridLayer get _currentLayer => _availableLayers[_currentIndex];

  void _cyclePrev() {
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _availableLayers.length) %
          _availableLayers.length;
    });
  }

  void _cycleNext() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _availableLayers.length;
    });
  }

  // Row widgets mutate character.configMedia / session.configMedia in
  // place; nothing the body watches notifies on those mutations. The
  // empty setState forces a rebuild so resolveMedia is re-run and the
  // new views propagate to all rows.
  void _onRowChanged() {
    // ignore: qcheck/avoid_empty_setstate
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>().settings;
    // One resolveMedia call per column. The character view sees only
    // character + app (session null); the app view sees only app. Each
    // cell renders from its own column's view so labels reflect what
    // that layer would apply in isolation.
    final views = (
      app: resolveMedia(settings: settings, pureHelpers: _pureHelpers),
      character: resolveMedia(
        settings: settings,
        pureHelpers: _pureHelpers,
        character: widget.character,
      ),
      session: resolveMedia(
        settings: settings,
        pureHelpers: _pureHelpers,
        session: widget.chatSession,
        character: widget.character,
      ),
    );

    return IconTheme.merge(
      data: const IconThemeData(size: 20),
      child: ListTileTheme(
        data: const ListTileThemeData(dense: true),
        // LayoutBuilder gives us the constraints actually handed to this
        // widget — narrower than MediaQuery would report when the body is
        // embedded in a tab inside a dialog or split-pane. Below the
        // mobile breakpoint we collapse to a single value column with a
        // switcher; above, all available layers render side by side.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelColumnWidth = mediaSettingsGridLabelColumnWidth(
              constraints.maxWidth,
            );
            final isNarrow =
                constraints.maxWidth < AppConstants.mobileBreakpoint;
            final displayedLayers = isNarrow
                ? [_currentLayer]
                : _availableLayers;
            final showSwitcher = isNarrow && _availableLayers.length > 1;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildBody(
                    settings,
                    views,
                    labelColumnWidth,
                    displayedLayers,
                    showSwitcher,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    AppSettings settings,
    _ResolvedViews views,
    double labelColumnWidth,
    List<MediaSettingsGridLayer> displayedLayers,
    bool showSwitcher,
  ) {
    final widgets = <Widget>[
      MediaSettingsGridHeader(
        layers: displayedLayers,
        characterName: widget.character?.card.displayName ?? '',
        labelColumnWidth: labelColumnWidth,
        showSwitcher: showSwitcher,
        onCyclePrev: showSwitcher ? _cyclePrev : null,
        onCycleNext: showSwitcher ? _cycleNext : null,
      ),
    ];

    final fieldsBySection = <String, List<MediaSettingsGridField>>{};
    for (final field in MediaSettingsGridField.values) {
      fieldsBySection.putIfAbsent(field.sectionLabel, () => []).add(field);
    }

    for (final entry in fieldsBySection.entries) {
      widgets.add(
        MediaDenseSection(
          headerLabel: entry.key,
          itemCount: entry.value.length,
          buildItem: (i) => _buildRow(
            // `i` is bounded by `itemCount: entry.value.length` above.
            // ignore: qcheck/avoid_unsafe_collection_methods
            entry.value[i],
            settings,
            views,
            labelColumnWidth,
            displayedLayers,
          ),
          dividerIndent: labelColumnWidth,
        ),
      );
    }

    return widgets;
  }

  // ignore: qcheck/avoid_returning_widgets
  Widget _buildRow(
    MediaSettingsGridField field,
    AppSettings settings,
    _ResolvedViews views,
    double labelColumnWidth,
    List<MediaSettingsGridLayer> displayedLayers,
  ) {
    switch (field.cellType) {
      case MediaSettingsGridCellType.preset:
        return MediaSettingsPresetRow(
          field: field,
          displayedLayers: displayedLayers,
          labelColumnWidth: labelColumnWidth,
          character: widget.character,
          chatSession: widget.chatSession,
          chatPageController: widget.chatPageController,
          settings: settings,
          pureHelpers: _pureHelpers,
          onChanged: _onRowChanged,
        );
      case MediaSettingsGridCellType.dropdown:
        return MediaSettingsDropdownRow(
          field: field,
          displayedLayers: displayedLayers,
          labelColumnWidth: labelColumnWidth,
          character: widget.character,
          chatSession: widget.chatSession,
          chatPageController: widget.chatPageController,
          characterView: views.character,
          sessionView: views.session,
          onChanged: _onRowChanged,
        );
      case MediaSettingsGridCellType.tristate:
        return MediaSettingsTristateRow(
          field: field,
          displayedLayers: displayedLayers,
          labelColumnWidth: labelColumnWidth,
          character: widget.character,
          chatSession: widget.chatSession,
          chatPageController: widget.chatPageController,
          onChanged: _onRowChanged,
        );
      case MediaSettingsGridCellType.text:
        return MediaSettingsTextRow(
          field: field,
          displayedLayers: displayedLayers,
          labelColumnWidth: labelColumnWidth,
          character: widget.character,
          onChanged: _onRowChanged,
        );
    }
  }
}
