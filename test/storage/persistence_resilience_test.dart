import 'dart:convert';
import 'dart:io';

import 'package:cardwave/chat/src/repositories/io_chat.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/repositories/settings_repository.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Regression tests for the corrupt-data resilience fixes (F1, F6) and the
/// PNG-backup exclusion (F19). Each exercises the real native AppStorage
/// against a throwaway temp directory.
void main() {
  late Directory tmp;
  // Mutable so the single AppStorage init (its pathResolver is `late final`,
  // one-shot) can be pointed at a fresh temp dir per test.
  late String settingsDir;
  late String cardsDir;

  setUpAll(() async {
    await AppStorage.instance.init((domain) {
      switch (domain) {
        case StorageDomainEnum.settings:
          return settingsDir;
        case StorageDomainEnum.cards:
          return cardsDir;
      }
    });
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cardwave_persist_test');
    settingsDir = p.join(tmp.path, 'settings');
    cardsDir = p.join(tmp.path, 'cards');
    Directory(settingsDir).createSync(recursive: true);
    Directory(cardsDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('F1: corrupt settings.json (JSON array) degrades to {} not a crash',
      () async {
    final repo = SettingsRepository()..init(settingsDir);
    // A JSON array where a Map is expected: `jsonDecode(...) as Map` throws a
    // TypeError (an Error, not an Exception). The plain catch must swallow it.
    await AppStorage.instance.writeString(
      StorageDomainEnum.settings,
      AppConstants.settingsFileName,
      '[1,2,3]',
    );

    final map = await repo.loadSettings();

    expect(map, isEmpty);
  });

  test(
    'F6: one corrupt session.json is skipped; the index still lists the good '
    'session',
    () async {
      final ioChat = IOChat(
        loggingService: LoggingService(),
        appStorage: AppStorage.instance,
      );
      const chatDir = 'chatsForCard';

      // A well-formed session.
      final good = ChatSession(
        id: 'good',
        ownerId: 'card1',
        modelPresetId: 'preset',
        created: 1,
        lastActive: 2,
        name: 'Good session',
        isStreaming: false,
        isNsfw: false,
        isScenario: false,
        removeTrailingSentences: false,
        personaName: 'User',
        personaDescription: '',
        activeStickies: {},
        activeCooldowns: {},
        localVariables: {},
      );
      await AppStorage.instance.writeString(
        StorageDomainEnum.cards,
        p.posix.join(chatDir, 'good', 'session.json'),
        jsonEncode(good.toJson()),
      );

      // A structurally-wrong session.json (array, not object) — pre-fix this
      // threw a TypeError that aborted the whole rebuild.
      await AppStorage.instance.writeString(
        StorageDomainEnum.cards,
        p.posix.join(chatDir, 'bad', 'session.json'),
        '[]',
      );

      final index = await ioChat.getChatIndex(chatDir);

      expect(index.entries.map((e) => e.id), ['good']);
    },
  );

  test(
    'F2: atomic write replaces an existing file and leaves no .tmp behind',
    () async {
      // Every settings/chat re-save renames a `.tmp` over an existing
      // destination; if the platform rename refused to replace, all
      // second-and-later saves would fail.
      await AppStorage.instance.writeString(
        StorageDomainEnum.settings,
        AppConstants.settingsFileName,
        '{"v":1}',
      );
      await AppStorage.instance.writeString(
        StorageDomainEnum.settings,
        AppConstants.settingsFileName,
        '{"v":2}',
      );

      final content = await AppStorage.instance.readString(
        StorageDomainEnum.settings,
        AppConstants.settingsFileName,
      );

      expect(content, '{"v":2}');
      expect(
        File(
          p.join(settingsDir, '${AppConstants.settingsFileName}.tmp'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('F19: a `.png.bak` sidecar is excluded from a `.png` directory listing',
      () async {
    const dir = 'library';
    await AppStorage.instance.writeString(
      StorageDomainEnum.cards,
      p.posix.join(dir, 'card.png'),
      'fake-png',
    );
    await AppStorage.instance.writeString(
      StorageDomainEnum.cards,
      p.posix.join(dir, 'card.png.bak'),
      'fake-png-backup',
    );

    final pngs = await AppStorage.instance.listDirectory(
      StorageDomainEnum.cards,
      dir,
      extensions: ['.png'],
    );

    expect(pngs.map(p.posix.basename), ['card.png']);
  });
}
