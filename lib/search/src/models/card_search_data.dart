import 'dart:convert';
import 'dart:typed_data';

import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart'
    show embeddingsDim, embeddingsModelId;

/// Per-field cached data for one card: source-text hash, embedded vectors,
/// and lowercase tokens. The hash detects whether the source text has
/// changed since this entry was written; the vectors and tokens feed the
/// in-memory semantic + keyword indexes.
///
/// Maps are owned by `SearchService` and mutated in place as fields are
/// processed — callers must treat them as read-only.
class CardSearchData {
  const CardSearchData({
    required this.byField,
    required this.hashes,
    required this.tokens,
  });

  factory CardSearchData.empty() =>
      // Maps must stay mutable — SearchService mutates them in place.
      // ignore: prefer_const_constructors
      CardSearchData(byField: {}, hashes: {}, tokens: {});

  final Map<CardSearchFieldEnum, List<Float32List>> byField;
  final Map<CardSearchFieldEnum, String> hashes;
  final Map<CardSearchFieldEnum, List<String>> tokens;

  List<Float32List> chunksFor(CardSearchFieldEnum field) =>
      byField[field] ?? const [];

  List<String> tokensFor(CardSearchFieldEnum field) =>
      tokens[field] ?? const [];
}

/// `card.embedding.bin` codec: 'CWE1' magic + uint32 header_len + JSON
/// header (model, dim, per-field {name, hash, chunks, tokens}) +
/// 4-byte-aligned float32 blob in `CardSearchFieldEnum.values` order.
/// Returns null when the caller should discard the sidecar and re-process
/// every field — including any sidecar that lacks the `tokens` field.
class CardSearchSidecarCodec {
  const CardSearchSidecarCodec._();

  static const _magic = <int>[0x43, 0x57, 0x45, 0x31]; // 'CWE1'

  static const _keyModel = 'model';
  static const _keyDim = 'dim';
  static const _keyFields = 'fields';
  static const _keyName = 'name';
  static const _keyHash = 'hash';
  static const _keyChunks = 'chunks';
  static const _keyTokens = 'tokens';

  static Uint8List encode(CardSearchData data) {
    final fieldEntries = <Map<String, dynamic>>[];
    var totalFloats = 0;

    for (final field in CardSearchFieldEnum.values) {
      final chunks = data.byField[field] ?? const <Float32List>[];
      fieldEntries.add({
        _keyName: field.name,
        _keyHash: data.hashes[field] ?? '',
        _keyChunks: chunks.length,
        _keyTokens: data.tokens[field] ?? const <String>[],
      });
      for (final chunk in chunks) {
        totalFloats += chunk.length;
      }
    }

    final headerBytes = utf8.encode(
      jsonEncode({
        _keyModel: embeddingsModelId,
        _keyDim: embeddingsDim,
        _keyFields: fieldEntries,
      }),
    );
    final headerLen = headerBytes.length;
    final pad = (4 - (headerLen % 4)) % 4;

    final totalLen = 8 + headerLen + pad + totalFloats * 4;
    final out = Uint8List(totalLen);

    out.setRange(0, 4, _magic);
    ByteData.view(out.buffer).setUint32(4, headerLen, Endian.little);
    out.setRange(8, 8 + headerLen, headerBytes);

    var offset = 8 + headerLen + pad;
    for (final field in CardSearchFieldEnum.values) {
      final chunks = data.byField[field] ?? const <Float32List>[];
      for (final chunk in chunks) {
        final chunkBytes = chunk.buffer.asUint8List(
          chunk.offsetInBytes,
          chunk.lengthInBytes,
        );
        out.setRange(offset, offset + chunkBytes.length, chunkBytes);
        offset += chunkBytes.length;
      }
    }

    return out;
  }

  static CardSearchData? decode(Uint8List bytes) {
    if (bytes.length < 8) return null;
    for (var i = 0; i < 4; i++) {
      // `bytes` has >= 8 elements (checked above) and `_magic` is a 4-byte
      // const, so `i < 4` keeps both indices in bounds.
      // ignore: qcheck/avoid_unsafe_collection_methods
      if (bytes[i] != _magic[i]) return null;
    }

    final byteData = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final headerLen = byteData.getUint32(4, Endian.little);
    if (8 + headerLen > bytes.length) return null;

    final Map<String, dynamic> header;
    try {
      header =
          jsonDecode(
                utf8.decode(bytes.sublist(8, 8 + headerLen)),
              )
              as Map<String, dynamic>;
    } on FormatException {
      return null;
    }

    if (header[_keyModel] != embeddingsModelId) return null;
    if (header[_keyDim] != embeddingsDim) return null;

    final fields = header[_keyFields];
    if (fields is! List) return null;

    final pad = (4 - (headerLen % 4)) % 4;
    var offset = 8 + headerLen + pad;
    const chunkByteLen = embeddingsDim * 4;

    final byField = <CardSearchFieldEnum, List<Float32List>>{};
    final hashes = <CardSearchFieldEnum, String>{};
    final tokens = <CardSearchFieldEnum, List<String>>{};

    for (final entry in fields) {
      if (entry is! Map<String, dynamic>) return null;
      final name = entry[_keyName];
      final hash = entry[_keyHash];
      final chunkCount = entry[_keyChunks];
      final rawTokens = entry[_keyTokens];
      if (name is! String ||
          hash is! String ||
          chunkCount is! int ||
          rawTokens is! List) {
        return null;
      }

      final tokenList = <String>[];
      for (final t in rawTokens) {
        if (t is! String) return null;
        tokenList.add(t);
      }

      // Skip stored data for fields no longer in the enum (schema change);
      // missing fields will be detected as a per-field hash mismatch and
      // re-processed on demand.
      final field = _fieldByName(name);
      if (field == null) {
        offset += chunkCount * chunkByteLen;
        if (offset > bytes.length) return null;
        continue;
      }

      hashes[field] = hash;
      tokens[field] = tokenList;
      final fieldChunks = <Float32List>[];
      for (var i = 0; i < chunkCount; i++) {
        if (offset + chunkByteLen > bytes.length) return null;
        // View aliases the source buffer; safe because the caller's Uint8List
        // outlives the parsed CardSearchData (held via SearchService cache).
        fieldChunks.add(
          Float32List.view(
            bytes.buffer,
            bytes.offsetInBytes + offset,
            embeddingsDim,
          ),
        );
        offset += chunkByteLen;
      }
      byField[field] = fieldChunks;
    }

    return CardSearchData(byField: byField, hashes: hashes, tokens: tokens);
  }

  static CardSearchFieldEnum? _fieldByName(String name) {
    for (final f in CardSearchFieldEnum.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}
