import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave/search/src/observability/embeddings_loggers.dart';
import 'package:cardwave/search/src/repositories/io_search.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';
import 'package:cardwave_storage/cardwave_storage.dart';

/// Typed read/write of `FieldSearchData` against the per-card sidecar.
/// Returns `null` from [read] when the file is missing or fails to decode
/// — caller treats both cases as "process this card from scratch".
class SearchRepository {
  SearchRepository({required this.appStorage})
    : _ioSearch = IoSearch(appStorage: appStorage);

  final AppStorage appStorage;
  final IoSearch _ioSearch;

  // Card-shaped sidecar codec. Embedder dim/model are injected so the
  // retrieval package stays embedder-agnostic.
  static const _codec = VectorSidecarCodec<CardSearchFieldEnum>(
    fields: CardSearchFieldEnum.values,
    fieldByName: _fieldByName,
    dim: embeddingsDim,
    modelId: embeddingsModelId,
  );

  static CardSearchFieldEnum? _fieldByName(String name) {
    for (final f in CardSearchFieldEnum.values) {
      if (f.name == name) return f;
    }
    return null;
  }

  Future<FieldSearchData<CardSearchFieldEnum>?> read(
    String relativePath,
  ) async {
    if (!await _ioSearch.exists(relativePath)) return null;
    try {
      final bytes = await _ioSearch.read(relativePath);
      return _codec.decode(bytes);
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message:
              '[Search] Could not read sidecar $relativePath, will re-process: $e',
          error: e,
          stackTrace: st,
        ),
      );
      return null;
    }
  }

  Future<void> write(
    String relativePath,
    FieldSearchData<CardSearchFieldEnum> data,
  ) async {
    try {
      final bytes = _codec.encode(data);
      await _ioSearch.write(relativePath, bytes);
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Could not write sidecar $relativePath: $e',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }
}
