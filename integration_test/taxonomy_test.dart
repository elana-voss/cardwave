import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Single comprehensive taxonomy test, run inside one app boot.
///
/// Each `app.main()` initialises late-final fields on the singleton
/// services (e.g. `SettingsRepository._appDataPath`) and the second call
/// in the same process throws `LateInitializationError`. The convention
/// in this repo is therefore one `testWidgets` per file. The
/// "user-file-wins-over-bundle" case lives in
/// `taxonomy_user_file_test.dart` for the same reason — it needs a
/// different on-disk pre-seed.
///
/// No network, no LLM key — taxonomy is entirely offline.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'taxonomy — bundle loads on first launch, controller mutations persist, '
    'LLM prompt walks the tree',
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();

      app.main();
      await awaitAppReady(tester, timeout: const Duration(seconds: 30));

      final repo = tester
          .element(find.byType(MaterialApp))
          .read<TaxonomyRepository>();

      // 1) Bundled seed is loaded on first launch.
      expect(
        repo.getRootGroups(),
        isNotEmpty,
        reason: 'bundled asset should populate at least one root group',
      );
      expect(
        repo.getGroup('format'),
        isNotNull,
        reason: 'bundled asset must contain the "format" group',
      );
      expect(
        repo.getTag('fmt_character'),
        isNotNull,
        reason: 'bundled asset must contain "fmt_character" leaf',
      );

      // First-launch: the user-edits file must not exist yet. Web uses
      // AppStorage (IndexedDB-backed); native uses raw `dart:io File`.
      Future<bool> userFileExists() async {
        if (kIsWeb) {
          return AppStorage.instance.fileExists(
            StorageDomainEnum.settings,
            AppConstants.taxonomyFileName,
          );
        }
        final dir = await appDataDir();
        return File(
          '${dir.path}${Platform.pathSeparator}'
          '${AppConstants.taxonomyFileName}',
        ).existsSync();
      }

      Future<String> readUserFile() async {
        if (kIsWeb) {
          return AppStorage.instance.readString(
            StorageDomainEnum.settings,
            AppConstants.taxonomyFileName,
          );
        }
        final dir = await appDataDir();
        return File(
          '${dir.path}${Platform.pathSeparator}'
          '${AppConstants.taxonomyFileName}',
        ).readAsString();
      }

      expect(
        await userFileExists(),
        isFalse,
        reason: 'first launch must not write the user file',
      );

      // 2) LLM prompt rendering — every top-level group has a header,
      //    leaf ids appear, and exclusive tags carry the marker.
      final prompt = repo.getLlmPromptString();
      expect(prompt, isNotEmpty);
      for (final root in repo.getRootGroups()) {
        expect(
          prompt,
          contains('[${root.name}]'),
          reason: 'prompt must include header for "${root.name}"',
        );
      }
      expect(
        prompt,
        contains('fmt_character'),
        reason: 'leaf tag ids should appear in the prompt',
      );
      expect(
        prompt,
        contains('(EXCLUSIVE)'),
        reason: 'exclusive tags should be marked',
      );

      // 3) Controller add → save state advances, file lands on disk.
      final controller = TaxonomyEditorController(repo);
      addTearDown(controller.dispose);

      final addError = await controller.addGroup(
        groupId: 'test_root',
        name: 'Test Root',
        groupExplain: '',
      );
      expect(addError, isNull, reason: 'addGroup should succeed');
      expect(repo.getGroup('test_root')?.name, 'Test Root');
      expect(
        controller.lastSavedAt,
        isNotNull,
        reason: "first mutation should set the controller's lastSavedAt",
      );
      expect(controller.lastSaveError, isNull);

      final tagError = await controller.addTag(
        tagId: 'test_root_alpha',
        tagName: 'Alpha',
        tagExplain: '',
        synonyms: const ['First'],
        groupId: 'test_root',
        isExclusive: true,
      );
      expect(tagError, isNull);
      expect(repo.getTag('test_root_alpha')?.tagName, 'Alpha');

      // 4) Duplicate id rejected with a human-readable reason.
      final dup = await controller.addGroup(
        groupId: 'test_root',
        name: 'Dup',
        groupExplain: '',
      );
      expect(dup, contains('already exists'));

      // 5) Edit → rename + flag flip + synonyms update.
      final editError = await controller.updateTag(
        oldTagId: 'test_root_alpha',
        newTagId: 'test_root_alpha',
        tagName: 'Alpha (renamed)',
        tagExplain: 'updated',
        synonyms: const ['First', 'Initial'],
        groupId: 'test_root',
        isExclusive: false,
      );
      expect(editError, isNull);
      expect(repo.getTag('test_root_alpha')?.tagName, 'Alpha (renamed)');
      expect(repo.getTag('test_root_alpha')?.isExclusive, isFalse);

      // 6) Persisted file mirrors the in-memory state.
      expect(
        await userFileExists(),
        isTrue,
        reason: 'controller mutations should persist to disk',
      );
      final raw = jsonDecode(await readUserFile()) as Map<String, dynamic>;
      final groups = (raw['groups'] as List).cast<Map<String, dynamic>>();
      final tags = (raw['tags'] as List).cast<Map<String, dynamic>>();
      expect(
        groups.any((g) => g['group_id'] == 'test_root'),
        isTrue,
        reason: 'saved file must contain the added group',
      );
      expect(
        tags.any(
          (t) =>
              t['tag_id'] == 'test_root_alpha' &&
              t['tag_name'] == 'Alpha (renamed)' &&
              t['is_exclusive'] == false,
        ),
        isTrue,
        reason: 'saved file must contain the renamed, non-exclusive tag',
      );

      // 7) Delete cascades — group + its tags both gone.
      final delError = await controller.deleteGroup('test_root');
      expect(delError, isNull);
      expect(repo.getGroup('test_root'), isNull);
      expect(
        repo.getTag('test_root_alpha'),
        isNull,
        reason: 'group deletion should cascade to its tags',
      );
    },
  );
}
