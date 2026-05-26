import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/src/services/nodes_service.dart';

/// Opens the NODES debug snapshot dialog. CLAUDE.md keeps dialog
/// invocation out of widgets — the drawer tile dispatches here,
/// and the controller routes through [NavigationService].
class NodesDebugController {
  const NodesDebugController._();

  static Future<void> show({required NodesService nodesService}) =>
      NavigationService().showNodesDebugDialog(nodesService: nodesService);
}
