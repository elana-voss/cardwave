import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/src/media/media_resolver.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_dense_section.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_row.dart';
import 'package:cardwave/llm_app/src/models/config_media.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const String _emptyCell = '—';

/// Single shared "—" cell for layers that aren't applicable in the current
/// focus mode (e.g. character column in `appOnly`) or for app-layer cells
/// in dropdown/tristate rows (those fields don't exist at app layer).
const MediaSettingsGridCell _notApplicableCell = MediaSettingsGridCell(
  text: _emptyCell,
  state: MediaSettingsGridCellState.notApplicable,
  onTap: null,
);

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
/// Scaffold or AppBar of its own. Three live entry points feed it via
/// the [MediaSettingsGridFocus] argument:
///   - [MediaSettingsGridFocus.allColumns] — chat-drawer "Configure all".
///   - [MediaSettingsGridFocus.appOnly] — gear-menu "Media Defaults".
///   - [MediaSettingsGridFocus.appAndCharacter] — editor-drawer "Configure
///     media".
/// [MediaSettingsGridFocus.sessionOnly] has no live entry; kept for
/// symmetry.
///
/// The cell builders and writes branch on which layer-source widgets are
/// non-null, so `appOnly` passes null character + null session, and
/// `appAndCharacter` passes null session.
///
/// Reads values via [resolveMedia] and the raw layer storage classes;
/// writes go through `SettingsService.setDomainPreset` (app),
/// `CharacterService.queueJsonInCacheDebounced` (character), or
/// `ChatPageController.persistActiveChat` (session). After every write
/// the state class calls `setState(() {})` so tile subtitles reflect
/// the new value immediately — discrete-value tiles don't rebuild on
/// their own the way `TextEditingController`-bound widgets do.
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
  late final List<MediaSettingsGridLayer> _availableLayers =
      _resolveAvailableLayers();
  late int _currentIndex = _resolveInitialIndex();

  // `widget.character` / `widget.chatSession` unwrapped — only valid when
  // the corresponding layer exists (`widget.character != null` /
  // `widget.chatSession != null`); the per-layer write helpers below are
  // only ever invoked for layers that are present.
  CharacterFile get _character => widget.character!;
  ChatSession get _session => widget.chatSession!;

  // Stateless helper provided once at app scope — grab it here rather
  // than re-reading it from `context` on every build.
  late final LlmPureHelpers _pureHelpers;

  @override
  void initState() {
    super.initState();
    _pureHelpers = context.read<LlmPureHelpers>();
  }

  /// Layers in canonical display order: App on the left, then Character,
  /// then Current chat on the right. Character/Session are included only
  /// when their widget arg is non-null AND the focus mode covers them.
  List<MediaSettingsGridLayer> _resolveAvailableLayers() {
    switch (widget.focus) {
      case MediaSettingsGridFocus.appOnly:
        return const [MediaSettingsGridLayer.app];
      case MediaSettingsGridFocus.appAndCharacter:
        return [
          MediaSettingsGridLayer.app,
          if (widget.character != null) MediaSettingsGridLayer.character,
        ];
      case MediaSettingsGridFocus.allColumns:
        return [
          MediaSettingsGridLayer.app,
          if (widget.character != null) MediaSettingsGridLayer.character,
          if (widget.chatSession != null) MediaSettingsGridLayer.session,
        ];
      case MediaSettingsGridFocus.sessionOnly:
        return [
          if (widget.chatSession != null) MediaSettingsGridLayer.session,
        ];
    }
  }

  /// In narrow mode the switcher starts on the entry-point default
  /// (session for chat-drawer, character for editor-drawer, app for
  /// gear). Falls back to the last available layer if the default isn't
  /// in scope.
  int _resolveInitialIndex() {
    final entryDefault = switch (widget.focus) {
      MediaSettingsGridFocus.appOnly => MediaSettingsGridLayer.app,
      MediaSettingsGridFocus.appAndCharacter =>
        MediaSettingsGridLayer.character,
      MediaSettingsGridFocus.allColumns ||
      MediaSettingsGridFocus.sessionOnly => MediaSettingsGridLayer.session,
    };
    final idx = _availableLayers.indexOf(entryDefault);
    return idx >= 0 ? idx : _availableLayers.length - 1;
  }

  // `_availableLayers` is never empty and `_currentIndex` is kept within
  // bounds by `_resolveInitialIndex` and the modular `_cyclePrev`/`_cycleNext`.
  // ignore: qcheck/avoid_unsafe_collection_methods
  MediaSettingsGridLayer get _currentLayer => _availableLayers[_currentIndex];

  bool get _canCycle => _availableLayers.length > 1;

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
                    _pureHelpers,
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
    LlmPureHelpers pureHelpers,
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
            pureHelpers,
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

  // Dispatches on `field.cellType` to four sibling cell-builder methods;
  // extracting needs those four passed in or all moved together.
  // ignore: qcheck/avoid_returning_widgets
  Widget _buildRow(
    MediaSettingsGridField field,
    AppSettings settings,
    LlmPureHelpers pureHelpers,
    _ResolvedViews views,
    double labelColumnWidth,
    List<MediaSettingsGridLayer> displayedLayers,
  ) {
    final cells = switch (field.cellType) {
      MediaSettingsGridCellType.preset => _buildPresetCells(
        field,
        settings,
        pureHelpers,
      ),
      MediaSettingsGridCellType.dropdown => _buildDropdownCells(field, views),
      MediaSettingsGridCellType.tristate => _buildTristateCells(field),
      MediaSettingsGridCellType.text => _buildTextCells(field),
    };
    return MediaSettingsGridRow(
      label: field.label,
      layers: displayedLayers,
      appCell: cells.app,
      characterCell: cells.char,
      sessionCell: cells.session,
      labelColumnWidth: labelColumnWidth,
    );
  }

  // --- Preset cells (image / video / TTS model) -----------------------------

  ({
    MediaSettingsGridCell app,
    MediaSettingsGridCell char,
    MediaSettingsGridCell session,
  })
  _buildPresetCells(
    MediaSettingsGridField field,
    AppSettings settings,
    LlmPureHelpers pureHelpers,
  ) {
    final domain = _domainForPresetField(field);
    final profiles = settings.providerConfigs;

    final appId = settings.getAppDomainPresetId(domain);
    final charId = _readCharPresetId(field);
    final sessId = _readSessPresetId(field);

    final winner = sessId != null
        ? MediaSettingsGridLayer.session
        : charId != null
        ? MediaSettingsGridLayer.character
        : appId != null
        ? MediaSettingsGridLayer.app
        : null;

    // Cache label resolution by id — `_presetLabelOrFallback` scans every
    // provider × model × preset, and the same id is read up to three times
    // per preset row (winning + cell-by-cell) when layers share an id.
    final labelsById = <String, String>{};
    String labelOfId(String id) => labelsById.putIfAbsent(
      id,
      () => _presetLabelOrFallback(pureHelpers, profiles, id),
    );

    // Per-column display id walks only the layers below the current
    // column: app has nothing below it, character falls back to app,
    // session falls back to character then app.
    String labelForColumn(String? own, String? inherited) {
      final id = own ?? inherited;
      return id == null ? _emptyCell : labelOfId(id);
    }

    final appCell = MediaSettingsGridCell(
      text: labelForColumn(appId, null),
      state: _stateFor(
        layer: MediaSettingsGridLayer.app,
        layerHasOwn: appId != null,
        winner: winner,
      ),
      onTap: (cellContext) => _onPresetCellTap(
        cellContext: cellContext,
        field: field,
        layer: MediaSettingsGridLayer.app,
        layerHasOwn: appId != null,
        pureHelpers: pureHelpers,
        profiles: profiles,
        currentLayerId: appId,
      ),
    );
    final charCell = widget.character == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(charId, appId),
            state: _stateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charId != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onPresetCellTap(
              cellContext: cellContext,
              field: field,
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charId != null,
              pureHelpers: pureHelpers,
              profiles: profiles,
              currentLayerId: charId,
            ),
          );
    final sessCell = widget.chatSession == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(sessId, charId ?? appId),
            state: _stateFor(
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessId != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onPresetCellTap(
              cellContext: cellContext,
              field: field,
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessId != null,
              pureHelpers: pureHelpers,
              profiles: profiles,
              currentLayerId: sessId,
            ),
          );

    return (app: appCell, char: charCell, session: sessCell);
  }

  Future<void> _onPresetCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required LlmPureHelpers pureHelpers,
    required List<LlmProviderConfig> profiles,
    required String? currentLayerId,
  }) async {
    if (layer == MediaSettingsGridLayer.app) {
      final ok = await NavigationService().showConfirmCancelDialog(
        title: 'Change app default?',
        message: 'This affects every chat. Continue?',
        confirmText: 'Continue',
        confirmColor: Theme.of(context).colorScheme.primary,
      );
      if (!ok || !mounted) return;
    }

    if (!layerHasOwn) {
      await _openPresetPicker(field, layer, pureHelpers, profiles, null);
      return;
    }
    if (!cellContext.mounted) return;
    final action = await _showLayeredCellActionMenu(cellContext);
    if (action == null || !mounted) return;
    switch (action) {
      case _CellAction.change:
        await _openPresetPicker(
          field,
          layer,
          pureHelpers,
          profiles,
          currentLayerId,
        );
      case _CellAction.clear:
        _writePresetClear(field, layer);
        // Rebuild to reflect the just-cleared preset; the cleared value
        // lives in the settings/character object (and the clear kicks off
        // an async save) — not state that belongs in a setState closure.
        // ignore: qcheck/avoid_empty_setstate
        setState(() {});
    }
  }

  Future<void> _openPresetPicker(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
    LlmPureHelpers pureHelpers,
    List<LlmProviderConfig> profiles,
    String? activePresetId,
  ) async {
    final domain = _domainForPresetField(field);
    final validPresets = pureHelpers.getValidPresetsForDomain(domain, profiles);
    if (validPresets.isEmpty || !mounted) return;
    final pickedId = await DialogPresetPicker.show(
      context: context,
      title: Text(
        'Choose a ${domain.label.toLowerCase()} model',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      validPresets: validPresets,
      activePresetId: activePresetId,
    );
    if (pickedId == null || !mounted) return;
    final newPreset = pureHelpers.resolvePresetOrNull(
      configId: pickedId,
      providers: profiles,
    );
    if (newPreset == null) return;
    _writePresetSet(field, layer, pickedId, newPreset.model);
    setState(() {});
  }

  void _writePresetSet(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
    String presetId,
    LlmModel model,
  ) {
    switch (layer) {
      case MediaSettingsGridLayer.app:
        unawaited(
          context.read<SettingsService>().setDomainPreset(
            _domainForPresetField(field),
            presetId,
          ),
        );
      case MediaSettingsGridLayer.character:
        final char = widget.character;
        if (char == null) return;
        _ensureCharacterConfigMedia();
        final cm = char.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(presetId, firstImageAspectRatioId(model));
          case MediaSettingsGridField.videoModel:
            final opts = firstVideoOptions(model);
            if (opts == null) return;
            cm.setVideoPreset(
              presetId,
              opts.resolutionId,
              opts.aspectRatioId,
              opts.durationSeconds,
            );
          case MediaSettingsGridField.ttsModel:
            final opts = firstTtsOptions(model);
            if (opts == null) return;
            cm.setTtsPreset(presetId, opts.voiceId, opts.languageCode);
          // ignore: no_default_cases
          default:
            return;
        }
        context.read<CharacterService>().queueJsonInCacheDebounced(char);
      case MediaSettingsGridLayer.session:
        final session = widget.chatSession;
        final controller = widget.chatPageController;
        if (session == null || controller == null) return;
        _ensureSessionConfigMedia();
        final cm = session.configMedia!;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(presetId, firstImageAspectRatioId(model));
          case MediaSettingsGridField.videoModel:
            final opts = firstVideoOptions(model);
            if (opts == null) return;
            cm.setVideoPreset(
              presetId,
              opts.resolutionId,
              opts.aspectRatioId,
              opts.durationSeconds,
            );
          case MediaSettingsGridField.ttsModel:
            final opts = firstTtsOptions(model);
            if (opts == null) return;
            cm.setTtsPreset(presetId, opts.voiceId, opts.languageCode);
          // ignore: no_default_cases
          default:
            return;
        }
        unawaited(controller.persistActiveChat());
    }
  }

  void _writePresetClear(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
  ) {
    switch (layer) {
      case MediaSettingsGridLayer.app:
        unawaited(
          context.read<SettingsService>().setDomainPreset(
            _domainForPresetField(field),
            null,
          ),
        );
      case MediaSettingsGridLayer.character:
        final char = widget.character;
        final cm = char?.configMedia;
        if (char == null || cm == null) return;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(null, null);
          case MediaSettingsGridField.videoModel:
            cm.setVideoPreset(null, null, null, null);
          case MediaSettingsGridField.ttsModel:
            cm.setTtsPreset(null, null, null);
          // ignore: no_default_cases
          default:
            return;
        }
        context.read<CharacterService>().queueJsonInCacheDebounced(char);
      case MediaSettingsGridLayer.session:
        final session = widget.chatSession;
        final controller = widget.chatPageController;
        final cm = session?.configMedia;
        if (session == null || controller == null || cm == null) return;
        switch (field) {
          case MediaSettingsGridField.imageModel:
            cm.setImagePreset(null, null);
          case MediaSettingsGridField.videoModel:
            cm.setVideoPreset(null, null, null, null);
          case MediaSettingsGridField.ttsModel:
            cm.setTtsPreset(null, null, null);
          // ignore: no_default_cases
          default:
            return;
        }
        unawaited(controller.persistActiveChat());
    }
  }

  // --- Dropdown cells (aspect / resolution / duration / voice / language) ---

  ({
    MediaSettingsGridCell app,
    MediaSettingsGridCell char,
    MediaSettingsGridCell session,
  })
  _buildDropdownCells(MediaSettingsGridField field, _ResolvedViews views) {
    final charValue = _readCharDropdownValue(field);
    final sessValue = _readSessDropdownValue(field);

    final winner = sessValue != null
        ? MediaSettingsGridLayer.session
        : charValue != null
        ? MediaSettingsGridLayer.character
        : null;

    // Each column's preset comes from its own perspective view, so
    // dropdown options/labels match the model that column would apply
    // in isolation. A column without a preset at this perspective (no
    // own id and no fallback below) renders as not-applicable.
    final charPreset = _resolvedPresetFor(field, views.character);
    final sessPreset = _resolvedPresetFor(field, views.session);

    String labelFromView(ConfigMediaResolved view, ResolvedPreset preset) {
      final value = _seededDropdownValue(field, view);
      return value == null
          ? _emptyCell
          : _dropdownLabelFor(field, preset.model, value);
    }

    const appCell = _notApplicableCell;
    final charCell = widget.character == null || charPreset == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: labelFromView(views.character, charPreset),
            state: _stateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onDropdownCellTap(
              cellContext: cellContext,
              field: field,
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              currentValue: charValue,
              preset: charPreset,
            ),
          );
    final sessCell = widget.chatSession == null || sessPreset == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: labelFromView(views.session, sessPreset),
            state: _stateFor(
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onDropdownCellTap(
              cellContext: cellContext,
              field: field,
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessValue != null,
              currentValue: sessValue,
              preset: sessPreset,
            ),
          );

    return (app: appCell, char: charCell, session: sessCell);
  }

  Future<void> _onDropdownCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required String? currentValue,
    required ResolvedPreset preset,
  }) async {
    if (_isShortDropdown(field)) {
      await _openShortDropdownPopup(
        cellContext: cellContext,
        field: field,
        layer: layer,
        layerHasOwn: layerHasOwn,
        currentValue: currentValue,
        preset: preset,
      );
      return;
    }
    if (!layerHasOwn) {
      await _openDropdownPicker(field, layer, currentValue, preset);
      return;
    }
    final action = await _showLayeredCellActionMenu(cellContext);
    if (action == null || !mounted) return;
    switch (action) {
      case _CellAction.change:
        await _openDropdownPicker(field, layer, currentValue, preset);
      case _CellAction.clear:
        _writeDropdownClear(field, layer);
        // Rebuild to reflect the just-cleared value; it lives in the
        // settings/character object (and the clear kicks off an async
        // save) — not state that belongs in a setState closure.
        // ignore: qcheck/avoid_empty_setstate
        setState(() {});
    }
  }

  /// Aspect ratio, resolution, duration — short fixed lists where a
  /// popup menu (with optional Clear) replaces the dialog. TTS voice
  /// and language stay on the dialog flow because they can run to
  /// dozens of options with subtitles.
  bool _isShortDropdown(MediaSettingsGridField field) {
    return switch (field) {
      MediaSettingsGridField.imageAspectRatio ||
      MediaSettingsGridField.videoResolution ||
      MediaSettingsGridField.videoAspectRatio ||
      MediaSettingsGridField.videoDuration => true,
      // Only the four short fixed-list dropdowns qualify; the wildcard
      // deliberately covers every other field — listing all thirteen here
      // would duplicate the enum and obscure the intent.
      // ignore: qcheck/avoid_wildcard_cases_with_enums
      _ => false,
    };
  }

  Future<void> _openShortDropdownPopup({
    required BuildContext cellContext,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required String? currentValue,
    required ResolvedPreset preset,
  }) async {
    final options = _dropdownOptionsFor(field, preset.model);
    if (options.isEmpty) return;
    final position = _menuPositionFor(cellContext);
    if (position == null) return;
    final picked = await showMenu<_ShortDropdownPick>(
      context: cellContext,
      position: position,
      items: [
        for (final opt in options)
          CheckedPopupMenuItem<_ShortDropdownPick>(
            value: _ShortDropdownValue(opt.value),
            checked: opt.value == currentValue,
            child: Text(opt.label),
          ),
        if (layerHasOwn) const PopupMenuDivider(),
        if (layerHasOwn)
          const PopupMenuItem<_ShortDropdownPick>(
            value: _ShortDropdownClear(),
            child: Text('Clear'),
          ),
      ],
    );
    if (!mounted || picked == null) return;
    switch (picked) {
      case _ShortDropdownValue(:final value):
        _writeDropdownSet(field, layer, value);
      case _ShortDropdownClear():
        _writeDropdownClear(field, layer);
    }
    setState(() {});
  }

  Future<void> _openDropdownPicker(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
    String? currentValue,
    ResolvedPreset preset,
  ) async {
    final options = _dropdownOptionsFor(field, preset.model);
    if (options.isEmpty || !mounted) return;
    final picked = await showSelectionDialog<String>(
      context: context,
      title: field.label,
      activeValue: currentValue ?? options.first.value,
      options: options,
    );
    if (picked == null || !mounted) return;
    _writeDropdownSet(field, layer, picked);
    setState(() {});
  }

  void _writeDropdownSet(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
    String value,
  ) {
    switch (layer) {
      case MediaSettingsGridLayer.character:
        final char = widget.character;
        if (char == null) return;
        _ensureCharacterConfigMedia();
        _applyDropdownToCharacter(field, value);
        context.read<CharacterService>().queueJsonInCacheDebounced(char);
      case MediaSettingsGridLayer.session:
        final session = widget.chatSession;
        final controller = widget.chatPageController;
        if (session == null || controller == null) return;
        _ensureSessionConfigMedia();
        _applyDropdownToSession(field, value);
        unawaited(controller.persistActiveChat());
      case MediaSettingsGridLayer.app:
        return;
    }
  }

  void _writeDropdownClear(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
  ) {
    // Clearing a dropdown writes null while keeping the preset id intact.
    switch (layer) {
      case MediaSettingsGridLayer.character:
        final char = widget.character;
        final cm = char?.configMedia;
        if (char == null || cm == null) return;
        _clearDropdownOnCharacter(cm, field);
        context.read<CharacterService>().queueJsonInCacheDebounced(char);
      case MediaSettingsGridLayer.session:
        final session = widget.chatSession;
        final controller = widget.chatPageController;
        final cm = session?.configMedia;
        if (session == null || controller == null || cm == null) return;
        _clearDropdownOnSession(cm, field);
        unawaited(controller.persistActiveChat());
      case MediaSettingsGridLayer.app:
        return;
    }
  }

  void _applyDropdownToCharacter(MediaSettingsGridField field, String value) {
    final cm = _character.configMedia!;
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        cm.setImagePreset(cm.imagePresetId, value);
      case MediaSettingsGridField.videoResolution:
        cm.setVideoPreset(
          cm.videoPresetId,
          value,
          cm.videoAspectRatioId,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoAspectRatio:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          value,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoDuration:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          cm.videoAspectRatioId,
          int.parse(value),
        );
      case MediaSettingsGridField.ttsVoice:
        cm.setTtsPreset(cm.ttsPresetId, value, cm.ttsLanguageCode);
      case MediaSettingsGridField.ttsLanguage:
        cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, value);
      // ignore: no_default_cases
      default:
        return;
    }
  }

  void _applyDropdownToSession(MediaSettingsGridField field, String value) {
    final cm = _session.configMedia!;
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        cm.setImagePreset(cm.imagePresetId, value);
      case MediaSettingsGridField.videoResolution:
        cm.setVideoPreset(
          cm.videoPresetId,
          value,
          cm.videoAspectRatioId,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoAspectRatio:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          value,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoDuration:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          cm.videoAspectRatioId,
          int.parse(value),
        );
      case MediaSettingsGridField.ttsVoice:
        cm.setTtsPreset(cm.ttsPresetId, value, cm.ttsLanguageCode);
      case MediaSettingsGridField.ttsLanguage:
        cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, value);
      // ignore: no_default_cases
      default:
        return;
    }
  }

  void _clearDropdownOnCharacter(
    ConfigMediaCharacter cm,
    MediaSettingsGridField field,
  ) {
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        cm.setImagePreset(cm.imagePresetId, null);
      case MediaSettingsGridField.videoResolution:
        cm.setVideoPreset(
          cm.videoPresetId,
          null,
          cm.videoAspectRatioId,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoAspectRatio:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          null,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoDuration:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          cm.videoAspectRatioId,
          null,
        );
      case MediaSettingsGridField.ttsVoice:
        cm.setTtsPreset(cm.ttsPresetId, null, cm.ttsLanguageCode);
      case MediaSettingsGridField.ttsLanguage:
        cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, null);
      // ignore: no_default_cases
      default:
        return;
    }
  }

  void _clearDropdownOnSession(
    ConfigMediaSession cm,
    MediaSettingsGridField field,
  ) {
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        cm.setImagePreset(cm.imagePresetId, null);
      case MediaSettingsGridField.videoResolution:
        cm.setVideoPreset(
          cm.videoPresetId,
          null,
          cm.videoAspectRatioId,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoAspectRatio:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          null,
          cm.videoDurationSeconds,
        );
      case MediaSettingsGridField.videoDuration:
        cm.setVideoPreset(
          cm.videoPresetId,
          cm.videoResolutionId,
          cm.videoAspectRatioId,
          null,
        );
      case MediaSettingsGridField.ttsVoice:
        cm.setTtsPreset(cm.ttsPresetId, null, cm.ttsLanguageCode);
      case MediaSettingsGridField.ttsLanguage:
        cm.setTtsPreset(cm.ttsPresetId, cm.ttsVoiceId, null);
      // ignore: no_default_cases
      default:
        return;
    }
  }

  // --- Tristate cells (NSFW / selfie / video-send / web-fetch) --------------

  ({
    MediaSettingsGridCell app,
    MediaSettingsGridCell char,
    MediaSettingsGridCell session,
  })
  _buildTristateCells(MediaSettingsGridField field) {
    final charValue = _readCharBool(field);
    final sessValue = _readSessBool(field);

    final winner = sessValue != null
        ? MediaSettingsGridLayer.session
        : charValue != null
        ? MediaSettingsGridLayer.character
        : null;

    // App stores no tristate fields, so character's fallback is `false`
    // and session's fallback is whatever character set (or `false`).
    String labelForColumn(bool? own, bool inherited) {
      final v = own ?? inherited;
      return v ? 'On' : 'Off';
    }

    const appCell = _notApplicableCell;
    final charCell = widget.character == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(charValue, false),
            state: _stateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onTristateCellTap(
              cellContext: cellContext,
              field: field,
              layer: MediaSettingsGridLayer.character,
              currentValue: charValue,
            ),
          );
    final sessCell = widget.chatSession == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(sessValue, charValue ?? false),
            state: _stateFor(
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onTristateCellTap(
              cellContext: cellContext,
              field: field,
              layer: MediaSettingsGridLayer.session,
              currentValue: sessValue,
            ),
          );

    return (app: appCell, char: charCell, session: sessCell);
  }

  Future<void> _onTristateCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridField field,
    required MediaSettingsGridLayer layer,
    required bool? currentValue,
  }) async {
    final position = _menuPositionFor(cellContext);
    if (position == null) return;
    final picked = await showMenu<_TristatePick>(
      context: cellContext,
      position: position,
      items: [
        CheckedPopupMenuItem(
          value: _TristatePick.on,
          checked: currentValue == true,
          child: const Text('On'),
        ),
        CheckedPopupMenuItem(
          value: _TristatePick.off,
          checked: currentValue == false,
          child: const Text('Off'),
        ),
        CheckedPopupMenuItem(
          value: _TristatePick.inherit,
          checked: currentValue == null,
          child: const Text('Inherit'),
        ),
      ],
    );
    if (!mounted || picked == null) return;
    _writeTristate(field, layer, switch (picked) {
      _TristatePick.on => true,
      _TristatePick.off => false,
      _TristatePick.inherit => null,
    });
    setState(() {});
  }

  void _writeTristate(
    MediaSettingsGridField field,
    MediaSettingsGridLayer layer,
    bool? value,
  ) {
    switch (layer) {
      case MediaSettingsGridLayer.character:
        final char = widget.character;
        if (char == null) return;
        _ensureCharacterConfigMedia();
        _applyTristateToCharacter(field, value);
        context.read<CharacterService>().queueJsonInCacheDebounced(char);
      case MediaSettingsGridLayer.session:
        final session = widget.chatSession;
        final controller = widget.chatPageController;
        if (session == null || controller == null) return;
        _ensureSessionConfigMedia();
        _applyTristateToSession(field, value);
        unawaited(controller.persistActiveChat());
      case MediaSettingsGridLayer.app:
        return;
    }
  }

  void _applyTristateToCharacter(MediaSettingsGridField field, bool? value) {
    final cm = _character.configMedia!;
    switch (field) {
      case MediaSettingsGridField.imageNsfwAllowed:
        cm.imageNsfwAllowed = value;
      case MediaSettingsGridField.imageToolSelfieAllowed:
        cm.imageToolSelfieAllowed = value;
      case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
        cm.imageToolSelfieCaptionsAllowed = value;
      case MediaSettingsGridField.videoNsfwAllowed:
        cm.videoNsfwAllowed = value;
      case MediaSettingsGridField.videoToolSendAllowed:
        cm.videoToolSendAllowed = value;
      case MediaSettingsGridField.webToolFetchAllowed:
        cm.webToolFetchAllowed = value;
      // ignore: no_default_cases
      default:
        return;
    }
  }

  void _applyTristateToSession(MediaSettingsGridField field, bool? value) {
    final cm = _session.configMedia!;
    switch (field) {
      case MediaSettingsGridField.imageNsfwAllowed:
        cm.imageNsfwAllowed = value;
      case MediaSettingsGridField.imageToolSelfieAllowed:
        cm.imageToolSelfieAllowed = value;
      case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
        cm.imageToolSelfieCaptionsAllowed = value;
      case MediaSettingsGridField.videoNsfwAllowed:
        cm.videoNsfwAllowed = value;
      case MediaSettingsGridField.videoToolSendAllowed:
        cm.videoToolSendAllowed = value;
      case MediaSettingsGridField.webToolFetchAllowed:
        cm.webToolFetchAllowed = value;
      // ignore: no_default_cases
      default:
        return;
    }
  }

  // --- Text cells (image / video prompt prefix) -----------------------------
  // Character-only field — app and session columns render as not-applicable
  // because the prompt prefix is character-ship persona flavour, with no
  // app-default or per-chat override semantics (see `ConfigMediaCharacter`
  // doc).

  ({
    MediaSettingsGridCell app,
    MediaSettingsGridCell char,
    MediaSettingsGridCell session,
  })
  _buildTextCells(MediaSettingsGridField field) {
    final charValue = _readCharPromptPrefix(field);
    final winner = charValue != null ? MediaSettingsGridLayer.character : null;

    final charCell = widget.character == null
        ? _notApplicableCell
        : MediaSettingsGridCell(
            text: charValue ?? _emptyCell,
            state: _stateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onTextCellTap(
              cellContext: cellContext,
              field: field,
              currentValue: charValue,
            ),
          );

    return (
      app: _notApplicableCell,
      char: charCell,
      session: _notApplicableCell,
    );
  }

  Future<void> _onTextCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridField field,
    required String? currentValue,
  }) async {
    if (currentValue == null) {
      await _openTextPrefixDialog(field, null);
      return;
    }
    final action = await _showLayeredCellActionMenu(cellContext);
    if (action == null || !mounted) return;
    switch (action) {
      case _CellAction.change:
        await _openTextPrefixDialog(field, currentValue);
      case _CellAction.clear:
        _writePromptPrefix(field, null);
        // Rebuild to reflect the just-cleared prefix; it lives on the
        // character's configMedia (and the write kicks off an async save)
        // — not state that belongs in a setState closure.
        // ignore: qcheck/avoid_empty_setstate
        setState(() {});
    }
  }

  Future<void> _openTextPrefixDialog(
    MediaSettingsGridField field,
    String? currentValue,
  ) async {
    final result = await showCharacterPromptPrefixDialog(
      context,
      domain: _domainForTextField(field),
      currentValue: currentValue,
    );
    if (result == null || !mounted) return;
    _writePromptPrefix(field, result);
    setState(() {});
  }

  void _writePromptPrefix(MediaSettingsGridField field, String? value) {
    final char = widget.character;
    if (char == null) return;
    _ensureCharacterConfigMedia();
    final cm = char.configMedia!;
    final stored = (value == null || value.isEmpty) ? null : value;
    switch (field) {
      case MediaSettingsGridField.imagePromptPrefix:
        cm.imagePromptPrefix = stored;
      case MediaSettingsGridField.videoPromptPrefix:
        cm.videoPromptPrefix = stored;
      // ignore: no_default_cases
      default:
        return;
    }
    context.read<CharacterService>().queueJsonInCacheDebounced(char);
  }

  PromptPrefixDomain _domainForTextField(MediaSettingsGridField field) {
    switch (field) {
      case MediaSettingsGridField.imagePromptPrefix:
        return PromptPrefixDomain.image;
      case MediaSettingsGridField.videoPromptPrefix:
        return PromptPrefixDomain.video;
      // ignore: no_default_cases
      default:
        throw StateError('Not a prompt prefix field: $field');
    }
  }

  // --- Read helpers ---------------------------------------------------------

  String? _readCharPresetId(MediaSettingsGridField field) {
    final cm = widget.character?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageModel:
        return cm.imagePresetId;
      case MediaSettingsGridField.videoModel:
        return cm.videoPresetId;
      case MediaSettingsGridField.ttsModel:
        return cm.ttsPresetId;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  String? _readSessPresetId(MediaSettingsGridField field) {
    final cm = widget.chatSession?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageModel:
        return cm.imagePresetId;
      case MediaSettingsGridField.videoModel:
        return cm.videoPresetId;
      case MediaSettingsGridField.ttsModel:
        return cm.ttsPresetId;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  String? _readCharDropdownValue(MediaSettingsGridField field) {
    final cm = widget.character?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        return cm.imageAspectRatioId;
      case MediaSettingsGridField.videoResolution:
        return cm.videoResolutionId;
      case MediaSettingsGridField.videoAspectRatio:
        return cm.videoAspectRatioId;
      case MediaSettingsGridField.videoDuration:
        return cm.videoDurationSeconds?.toString();
      case MediaSettingsGridField.ttsVoice:
        return cm.ttsVoiceId;
      case MediaSettingsGridField.ttsLanguage:
        return cm.ttsLanguageCode;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  String? _readSessDropdownValue(MediaSettingsGridField field) {
    final cm = widget.chatSession?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        return cm.imageAspectRatioId;
      case MediaSettingsGridField.videoResolution:
        return cm.videoResolutionId;
      case MediaSettingsGridField.videoAspectRatio:
        return cm.videoAspectRatioId;
      case MediaSettingsGridField.videoDuration:
        return cm.videoDurationSeconds?.toString();
      case MediaSettingsGridField.ttsVoice:
        return cm.ttsVoiceId;
      case MediaSettingsGridField.ttsLanguage:
        return cm.ttsLanguageCode;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  bool? _readCharBool(MediaSettingsGridField field) {
    final cm = widget.character?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageNsfwAllowed:
        return cm.imageNsfwAllowed;
      case MediaSettingsGridField.imageToolSelfieAllowed:
        return cm.imageToolSelfieAllowed;
      case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
        return cm.imageToolSelfieCaptionsAllowed;
      case MediaSettingsGridField.videoNsfwAllowed:
        return cm.videoNsfwAllowed;
      case MediaSettingsGridField.videoToolSendAllowed:
        return cm.videoToolSendAllowed;
      case MediaSettingsGridField.webToolFetchAllowed:
        return cm.webToolFetchAllowed;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  /// Returns null for both null storage AND empty strings — callers treat
  /// "no value" as a single concept regardless of which one happens to be
  /// on disk.
  String? _readCharPromptPrefix(MediaSettingsGridField field) {
    final cm = widget.character?.configMedia;
    if (cm == null) return null;
    String? raw;
    switch (field) {
      case MediaSettingsGridField.imagePromptPrefix:
        raw = cm.imagePromptPrefix;
      case MediaSettingsGridField.videoPromptPrefix:
        raw = cm.videoPromptPrefix;
      // ignore: no_default_cases
      default:
        return null;
    }
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  bool? _readSessBool(MediaSettingsGridField field) {
    final cm = widget.chatSession?.configMedia;
    if (cm == null) return null;
    switch (field) {
      case MediaSettingsGridField.imageNsfwAllowed:
        return cm.imageNsfwAllowed;
      case MediaSettingsGridField.imageToolSelfieAllowed:
        return cm.imageToolSelfieAllowed;
      case MediaSettingsGridField.imageToolSelfieCaptionsAllowed:
        return cm.imageToolSelfieCaptionsAllowed;
      case MediaSettingsGridField.videoNsfwAllowed:
        return cm.videoNsfwAllowed;
      case MediaSettingsGridField.videoToolSendAllowed:
        return cm.videoToolSendAllowed;
      case MediaSettingsGridField.webToolFetchAllowed:
        return cm.webToolFetchAllowed;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  // --- Helpers --------------------------------------------------------------

  void _ensureCharacterConfigMedia() {
    final char = widget.character;
    assert(
      char != null,
      '_ensureCharacterConfigMedia: write path unreachable when character is null — focus mode hides the cell, so reaching this means the cell-state vs focus-mode invariant broke',
    );
    if (char == null) return;
    char.configMedia ??= ConfigMediaCharacter();
  }

  void _ensureSessionConfigMedia() {
    final session = widget.chatSession;
    assert(
      session != null,
      '_ensureSessionConfigMedia: write path unreachable when chatSession is null — focus mode hides the cell, so reaching this means the cell-state vs focus-mode invariant broke',
    );
    if (session == null) return;
    session.configMedia ??= ConfigMediaSession();
  }

  LlmProviderDomainEnum _domainForPresetField(MediaSettingsGridField field) {
    switch (field) {
      case MediaSettingsGridField.imageModel:
        return LlmProviderDomainEnum.image;
      case MediaSettingsGridField.videoModel:
        return LlmProviderDomainEnum.video;
      case MediaSettingsGridField.ttsModel:
        return LlmProviderDomainEnum.audioTts;
      // ignore: no_default_cases
      default:
        throw StateError('Not a preset field: $field');
    }
  }

  ResolvedPreset? _resolvedPresetFor(
    MediaSettingsGridField field,
    ConfigMediaResolved resolved,
  ) {
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        return resolved.imagePreset;
      case MediaSettingsGridField.videoResolution:
      case MediaSettingsGridField.videoAspectRatio:
      case MediaSettingsGridField.videoDuration:
        return resolved.videoPreset;
      case MediaSettingsGridField.ttsVoice:
      case MediaSettingsGridField.ttsLanguage:
        return resolved.ttsPreset;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  String? _seededDropdownValue(
    MediaSettingsGridField field,
    ConfigMediaResolved resolved,
  ) {
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        return resolved.imageAspectRatioId;
      case MediaSettingsGridField.videoResolution:
        return resolved.videoResolutionId;
      case MediaSettingsGridField.videoAspectRatio:
        return resolved.videoAspectRatioId;
      case MediaSettingsGridField.videoDuration:
        return resolved.videoDurationSeconds?.toString();
      case MediaSettingsGridField.ttsVoice:
        return resolved.ttsVoiceId;
      case MediaSettingsGridField.ttsLanguage:
        return resolved.ttsLanguageCode;
      // ignore: no_default_cases
      default:
        return null;
    }
  }

  List<SelectionOption<String>> _dropdownOptionsFor(
    MediaSettingsGridField field,
    LlmModel model,
  ) {
    switch (field) {
      case MediaSettingsGridField.imageAspectRatio:
        final aspects = model.optionsImage?.aspectRatios ?? const <ImageAspectRatio>[];
        return [
          for (final a in aspects)
            SelectionOption(value: a.id, label: a.label),
        ];
      case MediaSettingsGridField.videoResolution:
        final resolutions = model.optionsVideo?.resolutions ?? const <VideoResolution>[];
        return [
          for (final r in resolutions)
            SelectionOption(value: r.id, label: r.label),
        ];
      case MediaSettingsGridField.videoAspectRatio:
        final aspects = model.optionsVideo?.aspectRatios ?? const <VideoAspectRatio>[];
        return [
          for (final a in aspects)
            SelectionOption(value: a.id, label: a.label),
        ];
      case MediaSettingsGridField.videoDuration:
        final durations = model.optionsVideo?.durations ?? const <VideoDuration>[];
        return [
          for (final d in durations)
            SelectionOption(value: d.seconds.toString(), label: d.label),
        ];
      case MediaSettingsGridField.ttsVoice:
        final voices = model.optionsTts?.voices ?? const <TtsVoice>[];
        return [
          for (final v in voices)
            SelectionOption(value: v.id, label: v.label, subtitle: v.tone),
        ];
      case MediaSettingsGridField.ttsLanguage:
        final languages = model.optionsTts?.languages ?? const <TtsLanguage>[];
        return [
          for (final l in languages)
            SelectionOption(value: l.code, label: l.label, subtitle: l.code),
        ];
      // ignore: no_default_cases
      default:
        return const [];
    }
  }

  String _dropdownLabelFor(
    MediaSettingsGridField field,
    LlmModel model,
    String value,
  ) {
    final options = _dropdownOptionsFor(field, model);
    final hit = options.where((o) => o.value == value).firstOrNull;
    return hit?.label ?? value;
  }

  String _presetLabelOrFallback(
    LlmPureHelpers pureHelpers,
    List<LlmProviderConfig> profiles,
    String presetId,
  ) {
    final resolved = pureHelpers.resolvePresetOrNull(
      configId: presetId,
      providers: profiles,
    );
    if (resolved == null) return presetId;
    return '${LlmProvider.of(resolved.provider.providerEnum).label} · '
        '${resolved.preset.name}';
  }

  MediaSettingsGridCellState _stateFor({
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required MediaSettingsGridLayer? winner,
  }) {
    if (winner == layer) return MediaSettingsGridCellState.winning;
    if (layerHasOwn) return MediaSettingsGridCellState.overridden;
    return MediaSettingsGridCellState.inheriting;
  }

  /// Anchors any popup menu to the cell that was tapped. Mirrors how
  /// `PopupMenuButton` computes its own position — overlay-relative rect
  /// of the trigger widget.
  RelativeRect? _menuPositionFor(BuildContext cellContext) {
    final cellBox = cellContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(cellContext).context.findRenderObject() as RenderBox?;
    if (cellBox == null || overlay == null) return null;
    return RelativeRect.fromRect(
      Rect.fromPoints(
        cellBox.localToGlobal(Offset.zero, ancestor: overlay),
        cellBox.localToGlobal(
          cellBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }

  Future<_CellAction?> _showLayeredCellActionMenu(
    BuildContext cellContext,
  ) async {
    final position = _menuPositionFor(cellContext);
    if (position == null) return null;
    return showMenu<_CellAction>(
      context: cellContext,
      position: position,
      items: const [
        PopupMenuItem(value: _CellAction.change, child: Text('Change…')),
        PopupMenuItem(value: _CellAction.clear, child: Text('Clear')),
      ],
    );
  }
}

enum _CellAction { change, clear }

enum _TristatePick { on, off, inherit }

/// Result of a short-dropdown popup. Two variants so the dispatcher can
/// tell "user picked option X" from "user picked Clear" without resorting
/// to magic-string sentinels in the menu values.
sealed class _ShortDropdownPick {
  const _ShortDropdownPick();
}

final class _ShortDropdownValue extends _ShortDropdownPick {
  const _ShortDropdownValue(this.value);
  final String value;
}

final class _ShortDropdownClear extends _ShortDropdownPick {
  const _ShortDropdownClear();
}
