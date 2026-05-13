// Barrel file — public API for this domain.
// Files under src/ are private to this domain (enforced by import_lint).
// Cross-domain consumers MUST import this barrel, not src/ paths.

export 'src/controllers/group_chat_controller.dart';
export 'src/controllers/group_grid_controller.dart';
export 'src/models/chat_group.dart';
export 'src/models/group_activation_strategy_enum.dart';
export 'src/models/group_data.dart';
export 'src/models/group_file.dart';
export 'src/pages/group_chat_page.dart';
export 'src/pages/group_grid_page.dart';
export 'src/pages/widgets/dialog_group_overrides.dart';
export 'src/pages/widgets/group_character_tile.dart';
export 'src/repositories/group_repository.dart';
export 'src/repositories/io_group.dart';
export 'src/services/group_chat_service.dart';
export 'src/services/group_file_service.dart';
export 'src/services/group_prompt_service.dart';
