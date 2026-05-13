import 'dart:async';

import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/repositories/io_character.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/services.dart';

class CharacterRepository {
  CharacterRepository({required this.loggingService, required this.appStorage})
    : _ioCharacter = IOCharacter(
        loggingService: loggingService,
        appStorage: appStorage,
      );
  final LoggingService loggingService;
  final AppStorage appStorage;
  final IOCharacter _ioCharacter;

  Stream<CharacterFile> get onThumbnailGenerated =>
      _ioCharacter.onThumbnailGenerated;

  Future<List<CharacterFile>> readDirectory({
    void Function(CharacterLoadingPhaseEnum phase, int current, int total)?
    onProgress,
  }) {
    return _ioCharacter.readDirectory(onProgress: onProgress);
  }

  Future<void> deleteCharacter(CharacterFile characterFile) =>
      _ioCharacter.deleteCharacter(characterFile);

  Future<void> saveJsonInPNGandCache(CharacterFile characterFile) async {
    await _ioCharacter.saveJsonInPNGandCache(characterFile);
  }

  Future<void> replaceCharacterImage(
    CharacterFile characterFile,
    Uint8List newImageBytes,
  ) async {
    await _ioCharacter.replaceCharacterImage(characterFile, newImageBytes);
  }

  Future<void> saveJsonInCache(CharacterFile characterFile) async {
    await _ioCharacter.saveJsonInCache(characterFile);
  }

  Future<CharacterFile> cloneCharacter(CharacterFile original) {
    return _ioCharacter.cloneCharacter(original);
  }

  Future<CharacterFile> importCharacter(
    Uint8List bytes,
    String filename,
  ) {
    return _ioCharacter.importCharacter(bytes: bytes, filename: filename);
  }

  Future<void> ensureThumbnail(CharacterFile file) async {
    await _ioCharacter.ensureThumbnail(file);
  }

  Future<CharacterFile> createCharacter(
    String creator, {
    required String name,
    String? targetDirectory,
  }) async {
    Uint8List bytesToUse;
    final cardToUse = CharacterCardV3.createDefault();
    cardToUse.creator = creator;
    cardToUse.name = name;

    final byteData = await rootBundle.load(
      'assets/images/default_character.png',
    );
    bytesToUse = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    return _ioCharacter.createCharacter(
      card: cardToUse,
      imageBytes: bytesToUse,
      targetDirectory: targetDirectory,
    );
  }

  Future<bool> copyDefaultAssistant() async {
    final byteData = await rootBundle.load('assets/cards/Cass_Assistant.png');

    final bytesToUse = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    return _ioCharacter.ensureDefaultAssistantExists(
      bytesToUse,
      'Cass_Assistant.png',
    );
  }
}
