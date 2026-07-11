// Barrel file — public API for this domain.
// Files under src/ are private to this domain (enforced by import_lint).
// Cross-domain consumers MUST import this barrel, not src/ paths.

export 'src/controllers/personas_controller.dart';
export 'src/controllers/providers_controller.dart';
export 'src/controllers/settings_menu_controller.dart';
export 'src/models/app_settings.dart';
export 'src/models/chat_persona.dart';
export 'src/models/chat_theme.dart';
export 'src/models/llm_providers_recovery.dart';
export 'src/pages/app_card.dart';
export 'src/pages/app_drawer_page.dart';
export 'src/pages/app_end_drawer.dart';
export 'src/pages/dialog_ai_settings.dart';
export 'src/pages/widgets/dialog_language_picker.dart';
export 'src/pages/widgets/dialog_local_gguf_provider_config.dart';
export 'src/pages/widgets/dialog_local_provider_config.dart';
export 'src/pages/widgets/dialog_persona.dart';
export 'src/pages/widgets/dialog_preset_config.dart';
export 'src/pages/widgets/dialog_provider_config.dart';
export 'src/pages/widgets/dialog_taxonomy_editor.dart';
export 'src/pages/widgets/media_defaults_drawer_entry.dart';
export 'src/pages/widgets/settings_gear_menu.dart';
export 'src/pages/widgets/settings_tab_ai.dart';
export 'src/pages/widgets/settings_tab_ai/test_video_preview_dialog.dart';
export 'src/pages/widgets/settings_tab_ai/dialog_preset_picker.dart';
export 'src/pages/widgets/settings_tab_general.dart';
export 'src/pages/widgets/settings_tab_personas.dart';
export 'src/repositories/settings_repository.dart';
export 'src/utils/local_gguf_strings.dart';
export 'src/services/llm_management_service.dart';
export 'src/services/locale_controller.dart';
export 'src/services/settings_service.dart';
