import 'package:llamadart/llamadart.dart' show GpuDeviceInfo, GpuDeviceType;

/// Chooses which GPU to pin local-model offload to, from the full device list
/// a backend enumerated. Returns the value to pass as `mainGpu`: the position
/// of the chosen discrete GPU among the offload devices (the CPU device is
/// excluded from llama.cpp's offload list, so the index is counted over
/// non-CPU devices only).
///
/// Picks the discrete GPU with the most free memory. Returns null when there
/// is no discrete GPU to pin — no GPU at all, or only an integrated one (whose
/// memory is shared system RAM) — in which case the caller leaves the backend
/// on its default device handling. Memory alone can't decide this: an
/// integrated GPU often reports more (shared) memory than a discrete card's
/// dedicated VRAM, so the discrete type is the filter and free memory only
/// breaks ties between discrete cards.
int? pickDiscreteGpuIndex(List<GpuDeviceInfo> devices) {
  final offloadable = devices
      .where((d) => d.type != GpuDeviceType.cpu)
      .toList();
  int? bestOrdinal;
  var bestFree = -1;
  for (var i = 0; i < offloadable.length; i++) {
    final device = offloadable[i];
    if (device.type != GpuDeviceType.discreteGpu) continue;
    if (device.memoryFreeBytes > bestFree) {
      bestFree = device.memoryFreeBytes;
      bestOrdinal = i;
    }
  }
  return bestOrdinal;
}
