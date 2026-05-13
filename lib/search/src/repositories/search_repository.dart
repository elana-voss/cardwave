import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/src/models/card_search_data.dart';
import 'package:cardwave/search/src/observability/embeddings_loggers.dart';
import 'package:cardwave/search/src/repositories/io_search.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';

/// Typed read/write of `CardSearchData` against the per-card sidecar.
/// Returns `null` from [read] when the file is missing or fails to decode
/// — caller treats both cases as "process this card from scratch".
class SearchRepository {
  SearchRepository({required this.appStorage})
    : _ioSearch = IoSearch(appStorage: appStorage);

  final AppStorage appStorage;
  final IoSearch _ioSearch;

  Future<CardSearchData?> read(String relativePath) async {
    if (!await _ioSearch.exists(relativePath)) return null;
    try {
      final bytes = await _ioSearch.read(relativePath);
      return CardSearchSidecarCodec.decode(bytes);
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

  Future<void> write(String relativePath, CardSearchData data) async {
    try {
      final bytes = CardSearchSidecarCodec.encode(data);
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
