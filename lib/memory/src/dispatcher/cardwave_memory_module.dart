import 'package:cardwave/memory/src/services/memory_service.dart';

/// Single entry-point bundling the memory domain, held by the app via Provider
/// alongside the other Cardwave modules. Direct field access today; a future
/// `invoke(toolName, …)` + `listTools()` surface will wrap the same service for
/// cross-process deployment.
class CardwaveMemoryModule {
  const CardwaveMemoryModule({required this.memoryService});

  final MemoryService memoryService;
}
