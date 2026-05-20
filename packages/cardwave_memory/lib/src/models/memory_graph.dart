import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_memory/src/models/memory_field_enum.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/models/tree_node.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';
import 'package:json_annotation/json_annotation.dart';

part 'memory_graph.g.dart';

/// The per-chat memory unit: the flat list of [events], the [nodes] of the
/// story tree, and the [roots] (book-level node ids). Serializes to one JSON
/// file; the event [StoryEvent.vector]s travel in a binary sidecar instead,
/// since vectors-in-JSON cost ~3–4× the bytes.
@JsonSerializable(explicitToJson: true)
class MemoryGraph {
  const MemoryGraph({
    this.events = const [],
    this.nodes = const [],
    this.roots = const [],
  });

  factory MemoryGraph.fromJson(Map<String, dynamic> json) =>
      _$MemoryGraphFromJson(json);

  final List<StoryEvent> events;

  final List<TreeNode> nodes;

  final List<String> roots;

  Map<String, dynamic> toJson() => _$MemoryGraphToJson(this);

  // Event dense vectors travel in a `CWE1` sidecar — the same codec the card
  // search uses. dim/model are injected so the package stays embedder-
  // agnostic. Vectors pack under [MemoryFieldEnum.text], one chunk per event
  // in [events] order; the other fields are keyword-only and carry no vector.
  static const _vectorCodec = VectorSidecarCodec<MemoryFieldEnum>(
    fields: MemoryFieldEnum.values,
    dim: embeddingsDim,
    modelId: embeddingsModelId,
  );

  /// Packs every event's [StoryEvent.vector] into sidecar bytes, in [events]
  /// order. Call only once every event is embedded — pairs with
  /// [restoreVectors].
  Uint8List encodeVectors() {
    return _vectorCodec.encode(
      FieldSearchData<MemoryFieldEnum>(
        byField: {
          MemoryFieldEnum.text: [for (final event in events) event.vector!],
        },
        hashes: const {},
        tokens: const {},
      ),
    );
  }

  /// Restores [StoryEvent.vector]s from sidecar [bytes], zipping the decoded
  /// chunks back onto [events] in order. A stale sidecar (decode fails, or its
  /// vector count no longer matches [events]) leaves vectors null — the caller
  /// re-embeds, the same disposable-sidecar contract the codec already honors.
  void restoreVectors(Uint8List bytes) {
    final data = _vectorCodec.decode(bytes);
    if (data == null) return;
    final chunks = data.chunksFor(MemoryFieldEnum.text);
    if (chunks.length != events.length) return;
    final chunk = chunks.iterator;
    for (final event in events) {
      chunk.moveNext();
      event.vector = chunk.current;
    }
  }
}
