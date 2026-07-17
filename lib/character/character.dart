// Barrel file — public API for this domain.
// Files under src/ are private to this domain (enforced by import_lint).
// Cross-domain consumers MUST import this barrel, not src/ paths.

export 'src/controllers/ai_action_controller.dart';
export 'src/controllers/card_edit_gate_controller.dart';
export 'src/controllers/character_create_controller.dart';
export 'src/controllers/character_import_controller.dart';
export 'src/controllers/taxonomy_editor_controller.dart';
export 'src/models/card_list_item.dart';
export 'src/models/character_card_envelope.dart';
export 'src/models/character_card_v2.dart';
export 'src/models/character_card_v3.dart';
export 'src/models/character_file.dart';
export 'src/models/character_lorebook.dart';
export 'src/models/library_card_filter.dart';
export 'src/models/taxonomy_data.dart';
export 'src/models/taxonomy_group.dart';
export 'src/models/taxonomy_tag.dart';
export 'src/pages/widgets/dialog_card_edit_approval.dart';
export 'src/pages/widgets/dialog_character_prompt_prefix.dart';
export 'src/pages/widgets/prompt_prefix_domain.dart';
export 'src/repositories/character_repository.dart';
export 'src/repositories/io_character.dart';
export 'src/repositories/taxonomy_repository.dart';
export 'src/services/character_ai_service.dart';
export 'src/services/character_service.dart';
export 'src/utils/card_field_accessor.dart';
export 'src/utils/tag_normalizer.dart';
export 'src/utils/utils_png.dart';
