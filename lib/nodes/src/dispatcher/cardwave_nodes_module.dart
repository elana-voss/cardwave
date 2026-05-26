import 'package:cardwave/nodes/src/services/nodes_service.dart';

/// Single entry-point bundling the NODES domain, held by the app via
/// Provider alongside the other Cardwave modules. Direct field access
/// today; matches the wrapper-around-a-single-service shape
/// `CardwaveMemoryModule` uses next door.
class CardwaveNodesModule {
  const CardwaveNodesModule({required this.nodesService});

  final NodesService nodesService;
}
