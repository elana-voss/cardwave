import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai.dart';
import 'package:flutter/material.dart';

/// Which tab [DialogAiSettings] opens on. Order matches the on-screen
/// `TabBar` (`.index` is fed straight into `DefaultTabController`).
/// [icon] and [label] are the single source of truth for the tab's
/// visuals — reused by [DialogAiSettings]' tab strip, the gear-menu's
/// matching entries, and the drawer "Media Defaults" tile.
enum DialogAiSettingsTab {
  aiProviders(icon: Icons.electrical_services, label: 'AI Providers'),
  mediaDefaults(icon: Icons.tune, label: 'Media Defaults');

  const DialogAiSettingsTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Combined fullscreen AI settings dialog. Replaces the AppBar with a
/// CloseButton + TabBar row to reclaim the dead space — desktop AppBars
/// are tall and the tabs are the actual navigation here.
///
/// Tabs:
///   - **AI Providers** — provider catalog ([SettingsTabAi]): add/edit
///     providers, manage models, configure preset parameters.
///   - **Media Defaults** — multi-layer media settings via
///     [MediaSettingsGridBody]. The [mediaFocus] argument controls which
///     layer columns render (app-only, app+character, all three) so the
///     same dialog serves the gear-menu, editor-drawer and chat-drawer
///     entry points.
class DialogAiSettings extends StatelessWidget {
  const DialogAiSettings({
    super.key,
    this.initialTab = DialogAiSettingsTab.aiProviders,
    this.mediaFocus = MediaSettingsGridFocus.appOnly,
    this.chatSession,
    this.character,
    this.chatPageController,
  });

  final DialogAiSettingsTab initialTab;
  final MediaSettingsGridFocus mediaFocus;
  final ChatSession? chatSession;
  final CharacterFile? character;
  final ChatPageController? chatPageController;

  static Future<void> show(
    BuildContext context, {
    DialogAiSettingsTab initialTab = DialogAiSettingsTab.aiProviders,
    MediaSettingsGridFocus mediaFocus = MediaSettingsGridFocus.appOnly,
    ChatSession? chatSession,
    CharacterFile? character,
    ChatPageController? chatPageController,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => DialogAiSettings(
          initialTab: initialTab,
          mediaFocus: mediaFocus,
          chatSession: chatSession,
          character: character,
          chatPageController: chatPageController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: DialogAiSettingsTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Workaround for the fact that `TabBar` doesn't stretch to fill the AppBar.
              SizedBox(
                height: 46,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CloseButton(),
                    Expanded(
                      child: TabBar(
                        // Part of the workaround.
                        dividerColor: Colors.transparent,
                        tabs: [
                          // Icon + text on one row keeps the tab at the
                          // default text-tab height (46dp); using Tab's
                          // `icon` + `text` would stack them and grow to
                          // ~72dp, breaking the SizedBox above.
                          for (final tab in DialogAiSettingsTab.values)
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 8,
                                children: [
                                  Icon(tab.icon, size: 18),
                                  Text(tab.label),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    const SingleChildScrollView(child: SettingsTabAi()),
                    MediaSettingsGridBody(
                      focus: mediaFocus,
                      chatSession: chatSession,
                      character: character,
                      chatPageController: chatPageController,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
