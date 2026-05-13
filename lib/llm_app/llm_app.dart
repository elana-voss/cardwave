// Barrel file — public API for this domain.
// Files under src/ are private to this domain (enforced by import_lint).
// Cross-domain consumers MUST import this barrel, not src/ paths.
//
// llm_app is the glue domain between the LLM module and the rest of the app.
// It hosts the per-app/character/session media-config types and the resolver
// that merges them — code that knows about both `lib/llm/` (providers,
// presets, models) and the app domains (`lib/character/`, `lib/chat/`,
// `lib/settings/`).

export 'src/media/media_resolver.dart';
export 'src/media/media_validator.dart';
export 'src/media/widgets/media_settings_grid_field_enum.dart'
    show MediaSettingsGridFocus;
export 'src/media/widgets/media_settings_grid_page.dart'
    show MediaSettingsGridBody;
export 'src/models/config_media.dart';
