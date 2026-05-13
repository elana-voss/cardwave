import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/src/pages/dialog_ai_settings.dart';
import 'package:flutter/material.dart';

/// Stateless orchestrator for the gear-menu's navigation actions. All
/// pure UI navigation with no domain mutation; the controller exists so
/// the widget never calls `showDialog`/`Navigator.push` itself, keeping
/// the uniform "widgets dispatch, controllers navigate" rule consistent
/// across the codebase.
class SettingsMenuController {
  const SettingsMenuController._();

  /// Opens the combined AI dialog on the AI Providers tab.
  static void openAiProvidersTab(BuildContext context) {
    unawaited(DialogAiSettings.show(context));
  }

  /// Opens the App Settings tab as a dialog. Fire-and-forget.
  static void openAppSettingsTab() {
    unawaited(NavigationService().showSettingsGeneralDialog());
  }

  /// Pushes the Logs viewer onto the root navigator. Takes [context] because
  /// route pushes need an in-tree navigator and `NavigationService` doesn't
  /// expose one (its `navigatorKey` is the page-level navigator, not
  /// guaranteed to be the root).
  static void openLogsScreen(BuildContext context) {
    unawaited(
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => const CustomLogScreen(),
        ),
      ),
    );
  }

  /// Opens the combined AI dialog on the Media Defaults tab. [mediaFocus]
  /// selects which layer columns the grid renders (app-only / app + character
  /// / all three); [character], [chatSession], and [chatPageController] are
  /// the per-layer scope handles the grid needs to read and write the
  /// character and session layers. Defaults to the app-only focus so the
  /// gear-menu's "Media Defaults · App" entry can call this with no
  /// scope args.
  static void openMediaDefaults(
    BuildContext context, {
    MediaSettingsGridFocus mediaFocus = MediaSettingsGridFocus.appOnly,
    CharacterFile? character,
    ChatSession? chatSession,
    ChatPageController? chatPageController,
  }) {
    unawaited(
      DialogAiSettings.show(
        context,
        initialTab: DialogAiSettingsTab.mediaDefaults,
        mediaFocus: mediaFocus,
        character: character,
        chatSession: chatSession,
        chatPageController: chatPageController,
      ),
    );
  }
}
