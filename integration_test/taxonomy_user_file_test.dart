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

/// Verifies that a user-edited taxonomy file at
/// `<appData>/taxonomy.json` overrides the bundled seed on launch. Lives
/// in its own file because the boot-time pre-seed is incompatible with
/// the main taxonomy test (each `app.main()` call re-initialises
/// late-final fields and would throw on the second run).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'taxonomy — user file at appData wins over bundled asset on launch',
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();

      // Plant a tiny user-edited taxonomy BEFORE app boot. Web uses
      // AppStorage (IndexedDB-backed); native uses raw `dart:io File`.
      final customJson = jsonEncode({
        'groups': [
          {
            'group_id': 'only_one',
            'name': 'Only One',
            'parent_group_id': null,
            'display_order': 0,
          },
        ],
        'tags': [
          {
            'tag_id': 'only_tag',
            'tag_name': 'Only Tag',
            'tag_explain': '',
            'synonyms': <String>[],
            'group_id': 'only_one',
            'is_exclusive': true,
            'display_order': 0,
          },
        ],
      });
      if (kIsWeb) {
        await AppStorage.instance.init((_) => '');
        await AppStorage.instance.writeString(
          StorageDomainEnum.settings,
          AppConstants.taxonomyFileName,
          customJson,
        );
      } else {
        final dir = await appDataDir();
        final userFile = File(
          '${dir.path}${Platform.pathSeparator}'
          '${AppConstants.taxonomyFileName}',
        );
        await userFile.writeAsString(customJson);
      }

      app.main();
      await awaitAppReady(tester, timeout: const Duration(seconds: 30));

      final repo = tester
          .element(find.byType(MaterialApp))
          .read<TaxonomyRepository>();

      expect(
        repo.getRootGroups().length,
        1,
        reason: 'user file has exactly one root group; bundle would have many',
      );
      expect(repo.getGroup('only_one'), isNotNull);
      expect(repo.getTag('only_tag')?.tagName, 'Only Tag');
      expect(
        repo.getGroup('format'),
        isNull,
        reason:
            'bundled "format" group must NOT load when user file is present',
      );
    },
  );
}
