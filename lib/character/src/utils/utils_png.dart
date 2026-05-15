import 'dart:convert';
import 'dart:typed_data';

import 'package:cardwave/character/src/models/character_card_envelope.dart';
import 'package:cardwave/character/src/models/character_card_v2.dart';
import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:crclib/catalog.dart' as cat;
import 'package:crclib/crclib.dart' as crc;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

class PngParseException implements Exception {
  const PngParseException(this.cause, this.jsonData);
  final CheckedFromJsonException cause;
  final Map<String, dynamic> jsonData;

  @override
  String toString() {
    return 'PngParseException: ${cause.message}\nKey: ${cause.key}\nError: ${cause.innerError}';
  }
}

class UtilsPng {
  // ---------------------------------------------------------
  // Extracts character definition from PNG
  // ---------------------------------------------------------
  static CharacterCardV3 parsePng(Uint8List fileBytes) {
    final chunks = png_extract.extractChunks(fileBytes);
    final textChunks = chunks
        .where((chunk) => chunk['name'] == 'tEXt')
        .toList();

    String? v3Data;
    String? v2Data;

    for (final chunk in textChunks) {
      final data = chunk['data'] as Uint8List;
      // Per tEXt chunk spec, keyword is Latin-1, followed by null, then data.
      final nullIndex = data.indexOf(0);
      if (nullIndex != -1) {
        final keyword = latin1.decode(data.sublist(0, nullIndex));
        if (keyword == 'ccv3') {
          v3Data = latin1.decode(data.sublist(nullIndex + 1));
        } else if (keyword == 'chara') {
          v2Data = latin1.decode(data.sublist(nullIndex + 1));
        }
      }
    }

    // Prioritize V3 data if it exists, otherwise fall back to V2.
    final base64Data = v3Data ?? v2Data;

    if (base64Data != null) {
      final jsonData = utf8.decode(base64.decode(base64Data));
      final decodedData = jsonDecode(jsonData) as Map<String, dynamic>;
      try {
        if (decodedData.containsKey('data')) {
          final envelope = CharacterCardEnvelope.fromJson(decodedData);

          if (envelope.spec == 'chara_card_v2' ||
              envelope.specVersion == '2.0') {
            return CharacterCardV2.fromJson(envelope.data).toV3();
          }
          return CharacterCardV3.fromJson(envelope.data);
        }
        return CharacterCardV2.fromJson(decodedData).toV3();
      } on CheckedFromJsonException catch (e) {
        throw PngParseException(e, decodedData);
      }
    }

    throw const FormatException(
      'Error extracting JSON from PNG: No valid "ccv3" or "chara" tEXt chunk found.',
    );
  }

  //
  // Serializes card to JSON and stuffs JSON into pngBytes.
  //
  static Uint8List embedJsonInPng(CharacterCardV3 card, Uint8List pngBytes) {
    // V3 Chunk
    final v3Envelope = CharacterCardEnvelope(
      spec: 'chara_card_v3',
      specVersion: '3.0',
      data: card.toJson(),
    );
    final v3JsonData = jsonEncode(v3Envelope.toJson());
    final v3Base64Data = base64Encode(utf8.encode(v3JsonData));
    final v3ChunkData = latin1.encode('ccv3\x00$v3Base64Data');

    // V2 Chunk Fallback
    final v2Envelope = CharacterCardEnvelope(
      spec: 'chara_card_v2',
      specVersion: '2.0',
      data: card.toV2().toJson(),
    );
    final v2JsonData = jsonEncode(v2Envelope.toJson());
    final v2Base64Data = base64Encode(utf8.encode(v2JsonData));
    final v2ChunkData = latin1.encode('chara\x00$v2Base64Data');

    final chunks = png_extract.extractChunks(pngBytes);

    // Remove any existing 'chara' or 'ccv3' tEXt chunk to avoid duplicates
    chunks.removeWhere((chunk) {
      if (chunk['name'] == 'tEXt') {
        final data = chunk['data'] as Uint8List;
        // The keyword is Latin-1, up to the first null character.
        final nullIndex = data.indexOf(0);
        if (nullIndex != -1) {
          final keyword = latin1.decode(data.sublist(0, nullIndex));
          if (keyword == 'ccv3' || keyword == 'chara') {
            return true;
          }
        }
      }
      return false;
    });

    // Find where to insert the new chunk (before IEND)
    final iendIndex = chunks.indexWhere((chunk) => chunk['name'] == 'IEND');

    // Create the new chunk maps
    final v3Chunk = {'name': 'tEXt', 'data': v3ChunkData};
    final v2Chunk = {'name': 'tEXt', 'data': v2ChunkData};

    // Insert the new chunks before IEND
    if (iendIndex != -1) {
      chunks.insert(iendIndex, v3Chunk);
      chunks.insert(iendIndex + 1, v2Chunk);
    } else {
      chunks.add(v3Chunk);
      chunks.add(v2Chunk);
    }

    // Re-encode the PNG with the new chunk list
    final pngSignature = pngBytes.sublist(0, 8);
    final builder = BytesBuilder(copy: false);
    builder.add(pngSignature);

    for (final chunk in chunks) {
      final name = chunk['name'] as String;
      final data = chunk['data'] as Uint8List;

      final length = data.length;
      final lengthBytes = ByteData(4)..setUint32(0, length);
      builder.add(lengthBytes.buffer.asUint8List());

      final nameBytes = latin1.encode(name);
      builder.add(nameBytes);
      builder.add(data);

      crc.CrcValue? crcValue;
      final outputSink = ChunkedConversionSink<crc.CrcValue>.withCallback((
        accumulated,
      ) {
        // The CRC32 chunked conversion emits exactly one value on close.
        // ignore: qcheck/avoid_unsafe_collection_methods
        crcValue = accumulated.first;
      });
      final byteSink = cat.Crc32().startChunkedConversion(outputSink);
      byteSink.add(nameBytes);
      byteSink.add(data);
      byteSink.close();

      // `byteSink.close()` above flushes the chunked CRC32 conversion,
      // which fires the callback that sets `crcValue`.
      final crcVal = crcValue!;
      final crcBytes = ByteData(4)..setUint32(0, crcVal.toBigInt().toInt());
      builder.add(crcBytes.buffer.asUint8List());
    }
    return builder.toBytes();
  }

  static Future<void> exportAsPng(CharacterFile file) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    file.card.modificationDate = nowSeconds;
    file.card.creationDate ??= nowSeconds;

    final bytes = await AppStorage.instance.readBytes(
      StorageDomainEnum.cards,
      file.appCardImagePath,
    );
    final pngBytes = Uint8List.fromList(bytes);
    final pngBytesNew = embedJsonInPng(file.card, pngBytes);

    final safeName = UtilsApp.sanitizeFileName(file.card.name);
    String? savePath;
    if (!kIsWeb) {
      final result = await getSaveLocation(
        suggestedName: '$safeName.png',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PNG', extensions: ['png']),
        ],
      );

      if (result == null) return;
      savePath = result.path;
    }

    final xFile = XFile.fromData(
      pngBytesNew,
      mimeType: 'image/png',
      name: '$safeName.png',
    );
    await xFile.saveTo(savePath ?? '');
  }

  static Future<void> exportAsJson(
    CharacterFile characterFile, {
    bool asV2 = false,
  }) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    characterFile.card.modificationDate = nowSeconds;
    characterFile.card.creationDate ??= nowSeconds;

    final CharacterCardEnvelope envelope;
    if (asV2) {
      envelope = CharacterCardEnvelope(
        spec: 'chara_card_v2',
        specVersion: '2.0',
        data: characterFile.card.toV2().toJson(),
      );
    } else {
      envelope = CharacterCardEnvelope(
        spec: 'chara_card_v3',
        specVersion: '3.0',
        data: characterFile.card.toJson(),
      );
    }

    // Use pretty-printing for standalone JSON exports so they are human-readable
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(envelope.toJson());

    final safeName = UtilsApp.sanitizeFileName(characterFile.card.name);
    String? savePath;
    final versionSuffix = asV2 ? '_v2' : '_v3';
    if (!kIsWeb) {
      final result = await getSaveLocation(
        suggestedName: '$safeName$versionSuffix.json',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );

      if (result == null) return;
      savePath = result.path;
    }

    final textFile = XFile.fromData(
      Uint8List.fromList(utf8.encode(jsonString)),
      mimeType: 'application/json',
      name: '$safeName$versionSuffix.json',
    );
    await textFile.saveTo(savePath ?? '');
  }

  static bool hasCharaChunk(Uint8List bytes) {
    try {
      final chunks = png_extract.extractChunks(bytes);
      final textChunks = chunks
          .where((chunk) => chunk['name'] == 'tEXt')
          .toList();

      for (final chunk in textChunks) {
        final data = chunk['data'] as Uint8List;
        final nullIndex = data.indexOf(0);
        if (nullIndex != -1) {
          final keyword = latin1.decode(data.sublist(0, nullIndex));
          if (keyword == 'ccv3' || keyword == 'chara') {
            return true; // Found a valid character chunk
          }
        }
      }
      return false; // No character chunk found
    } on Exception {
      // Catches decoding errors or other issues.
      return false;
    }
  }
}
