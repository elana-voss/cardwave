import 'dart:typed_data';

import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_memory/src/models/memory_fact.dart';
import 'package:cardwave_memory/src/models/memory_field_enum.dart';
import 'package:cardwave_memory/src/models/memory_thread.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';
import 'package:json_annotation/json_annotation.dart';

part 'memory_graph.g.dart';

/// The per-chat memory unit: a flat list of [events] ("what happened") and a
/// flat list of [facts] ("what's true now" about the chat's entities).
/// Serializes to one JSON file; the event [StoryEvent.vector]s travel in a
/// binary sidecar instead, since vectors-in-JSON cost ~3–4× the bytes. Facts
/// carry no vector — they are recalled by entity name, not by similarity.
@JsonSerializable(explicitToJson: true)
class MemoryGraph {
  const MemoryGraph({
    this.events = const [],
    this.facts = const [],
    this.threads = const [],
  });

  factory MemoryGraph.fromJson(Map<String, dynamic> json) =>
      _$MemoryGraphFromJson(json);

  final List<StoryEvent> events;

  final List<MemoryFact> facts;

  /// Unresolved story threads ("what's pending"). Like [facts] they carry no
  /// vector — recalled by entity name, not similarity — so the sidecar is
  /// unchanged.
  final List<MemoryThread> threads;

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
