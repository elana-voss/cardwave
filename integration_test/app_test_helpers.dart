// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// API key for tests, supplied at test invocation via:
///   --dart-define=GROK_API_KEY=xai-...
/// Empty string means "no key supplied" — tests that need network must skip.
const String grokApiKey = String.fromEnvironment('GROK_API_KEY');

/// API key for NanoGPT tests. Supplied via:
///   --dart-define=NANOGPT_API_KEY=sk-nano-...
/// Used by the small subset of tests that need a second provider (e.g.
/// stale-preset fallback) so the difference between session-level override
/// and app-level default is observable.
const String nanogptApiKey = String.fromEnvironment('NANOGPT_API_KEY');

/// Set by the video test gate. Off by default to avoid spend on every run:
///   --dart-define=RUN_VIDEO=true
const bool runVideo =
    bool.hasEnvironment('RUN_VIDEO') &&
    String.fromEnvironment('RUN_VIDEO') != '' &&
    String.fromEnvironment('RUN_VIDEO') != 'false' &&
    String.fromEnvironment('RUN_VIDEO') != '0';

/// True when a Grok key was supplied. Tests that need real API calls should
/// guard with `if (!hasGrokKey) markTestSkipped(...)` before any real work.
bool get hasGrokKey => grokApiKey.isNotEmpty;

/// True when a NanoGPT key was supplied. Tests that exercise the
/// two-provider matrix should also gate on this.
bool get hasNanogptKey => nanogptApiKey.isNotEmpty;

/// Deletes every file in the app data directory so each test starts from
/// a fresh-install state. The directory itself stays so path_provider's
/// returned path remains valid. On Android, also wipes the sibling
/// `shared_prefs/` folder so any plugin-owned install registries can't
/// claim assets are present after the asset files have been removed.
///
/// On web, `path_provider` and `dart:io File` are unavailable, so the
/// equivalent wipe goes through [AppStorage] which routes to IndexedDB
/// (the same backing store the production app uses on web).
Future<void> wipeAppData() async {
  if (kIsWeb) {
    await AppStorage.instance.init((_) => '');
    for (final domain in StorageDomainEnum.values) {
      try {
        await AppStorage.instance.deleteDirectory(domain, '/');
      } on Exception catch (e) {
        print('[wipeAppData] could not wipe $domain: $e');
      }
    }
    return;
  }

  final dir = await getApplicationDocumentsDirectory();
  if (!dir.existsSync()) return;
  for (final entity in dir.listSync()) {
    try {
      entity.deleteSync(recursive: true);
    } on FileSystemException catch (e) {
      print('[wipeAppData] could not delete ${entity.path}: $e');
    }
  }
  if (Platform.isAndroid) {
    final prefsDir = Directory('${dir.parent.path}/shared_prefs');
    if (prefsDir.existsSync()) {
      try {
        prefsDir.deleteSync(recursive: true);
      } on FileSystemException catch (e) {
        print('[wipeAppData] could not delete shared_prefs: $e');
      }
    }
  }
}

/// Writes the recovery file with a Grok provider entry. On first launch, the
/// app sees no settings.json + a valid recovery file → seeds the provider,
/// then `MyApp`'s first-frame callback runs `rebuildFromRecovery` which
/// fetches Grok models, assigns default domain presets, and saves
/// settings.json. End state: a fully-configured app with one Grok provider,
/// onboarding skipped, ready to chat.
///
/// Returns true when the recovery file was written, false when no API key
/// is available (caller should skip).
Future<bool> seedGrokRecovery() async {
  if (!hasGrokKey) return false;
  if (kIsWeb) {
    await AppStorage.instance.init((_) => '');
    const recovery = LlmProvidersRecovery(
      characterPath: '',
      providers: [
        LlmProviderRecoveryEntry(
          id: 'grok-test',
          providerType: LLMProviderEnum.grok,
          apiKey: grokApiKey,
        ),
      ],
    );
    await AppStorage.instance.writeString(
      StorageDomainEnum.settings,
      AppConstants.llmProvidersRecoveryFileName,
      jsonEncode(recovery.toJson()),
    );
    return true;
  }
  final dir = await getApplicationDocumentsDirectory();
  final recoveryFile = File(
    '${dir.path}${Platform.pathSeparator}'
    '${AppConstants.llmProvidersRecoveryFileName}',
  );
  final recovery = LlmProvidersRecovery(
    characterPath: dir.path,
    providers: [
      const LlmProviderRecoveryEntry(
        id: 'grok-test',
        providerType: LLMProviderEnum.grok,
        apiKey: grokApiKey,
      ),
    ],
  );
  await recoveryFile.writeAsString(jsonEncode(recovery.toJson()));
  return true;
}

/// Seeds BOTH Grok and NanoGPT into the recovery file. Grok is listed
/// FIRST so `assignDefaultDomainPresetsIfEmpty` picks Grok as the
/// app-layer default for image/video/tts — tests that need an observable
/// "session override different from app default" pick a NanoGPT preset
/// at the session layer, so deletion of NanoGPT forces the resolver to
/// fall back to the Grok app default.
///
/// Returns true only when BOTH keys are present; caller should skip the
/// test when this returns false.
Future<bool> seedGrokAndNanogptRecovery() async {
  if (!hasGrokKey || !hasNanogptKey) return false;
  final providers = [
    const LlmProviderRecoveryEntry(
      id: 'grok-test',
      providerType: LLMProviderEnum.grok,
      apiKey: grokApiKey,
    ),
    const LlmProviderRecoveryEntry(
      id: 'nanogpt-test',
      providerType: LLMProviderEnum.nanogpt,
      apiKey: nanogptApiKey,
    ),
  ];
  if (kIsWeb) {
    await AppStorage.instance.init((_) => '');
    final recovery = LlmProvidersRecovery(
      characterPath: '',
      providers: providers,
    );
    await AppStorage.instance.writeString(
      StorageDomainEnum.settings,
      AppConstants.llmProvidersRecoveryFileName,
      jsonEncode(recovery.toJson()),
    );
    return true;
  }
  final dir = await getApplicationDocumentsDirectory();
  final recoveryFile = File(
    '${dir.path}${Platform.pathSeparator}'
    '${AppConstants.llmProvidersRecoveryFileName}',
  );
  final recovery = LlmProvidersRecovery(
    characterPath: dir.path,
    providers: providers,
  );
  await recoveryFile.writeAsString(jsonEncode(recovery.toJson()));
  return true;
}

/// Writes a minimal `cardwave_settings.json` that marks onboarding
/// complete and points `character_path` at the documents directory. App
/// boots straight to the grid (Cass is auto-copied by
/// `CharacterService.loadCharacters` regardless of recovery state). Use
/// when the test doesn't need any LLM provider pre-configured — the
/// local-provider tests in particular drive the add-provider UI flow
/// themselves rather than seeding via recovery.
///
/// Construct via the typed [AppSettings] model + `toJson()` so the
/// serialized shape always matches the current schema. A hand-rolled
/// map literal would silently drift the moment a required field is
/// added or renamed.
Future<void> seedOnboardingComplete() async {
  if (kIsWeb) {
    await AppStorage.instance.init((_) => '');
    final settings = AppSettings(
      characterPath: '',
      onboardingComplete: true,
    );
    await AppStorage.instance.writeString(
      StorageDomainEnum.settings,
      AppConstants.settingsFileName,
      jsonEncode(settings.toJson()),
    );
    return;
  }
  final dir = await getApplicationDocumentsDirectory();
  final settings = AppSettings(
    characterPath: dir.path,
    onboardingComplete: true,
  );
  final settingsFile = File(
    '${dir.path}${Platform.pathSeparator}${AppConstants.settingsFileName}',
  );
  await settingsFile.writeAsString(jsonEncode(settings.toJson()));
}

/// Copies the bundled Test_Character.png from `assets/test_cards/` into
/// the documents directory so the grid boots with TWO characters
/// (Cass + Test Character). Cass is auto-copied by `_copyDefaultAssistant`
/// on first launch; Test Character is NOT — it's only present when the
/// test explicitly seeds it. Call AFTER `wipeAppData` and BEFORE
/// `app.main()` so CharacterService picks it up on the initial scan.
Future<void> seedTestCharacter() async {
  final byteData = await rootBundle.load(
    'assets/test_cards/Test_Character.png',
  );
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
  if (kIsWeb) {
    await AppStorage.instance.init((_) => '');
    await AppStorage.instance.writeBytes(
      StorageDomainEnum.cards,
      'Test_Character.png',
      bytes,
    );
    return;
  }
  final dir = await getApplicationDocumentsDirectory();
  final cardFile = File(
    '${dir.path}${Platform.pathSeparator}Test_Character.png',
  );
  await cardFile.writeAsBytes(bytes);
}

/// Copies the bundled Vietnamese_Desc_Character.png — a card whose
/// `description` mentions "Vietnamese" but whose `name`, `tags`,
/// `personality`, and `scenario` do NOT contain that word. Used by the
/// lexical-field search test to assert a literal hit in a low-weighted
/// field still surfaces the card to the top of the relevance ranking.
///
/// Authoring contract for the bundled PNG:
///   - description: must contain the literal word "Vietnamese"
///   - name, tags, personality, scenario: must NOT contain "Vietnamese"
///   - name should be visibly distinct from "Cass | Assistant" so the
///     test can assert the first grid tile is not Cass.
Future<void> seedVietnameseDescriptionCharacter() async {
  final byteData = await rootBundle.load(
    'assets/test_cards/Vietnamese_Desc_Character.png',
  );
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
  if (kIsWeb) {
    await AppStorage.instance.init((_) => '');
    await AppStorage.instance.writeBytes(
      StorageDomainEnum.cards,
      'Vietnamese_Desc_Character.png',
      bytes,
    );
    return;
  }
  final dir = await getApplicationDocumentsDirectory();
  final cardFile = File(
    '${dir.path}${Platform.pathSeparator}Vietnamese_Desc_Character.png',
  );
  await cardFile.writeAsBytes(bytes);
}

/// The bundled assistant card's display name. Promoted to a constant so
/// an asset rename is a one-line change instead of a sweep across every
/// test that targets Cass.
const String kCassName = 'Cass | Assistant';

/// Scopes a finder to one CharacterGridItem identified by its display
/// name. The grid wraps each tile in a `KeyedSubtree` keyed
/// `'grid-card-<name>'` (see character_grid_page.dart) so tests can
/// look up a tile without depending on rendered text.
Finder findCharacterTile(String name) =>
    find.byKey(ValueKey('grid-card-$name'));

/// Taps the Icons.edit IconButton on a specific character's grid tile,
/// which routes via RouteEditCharacter directly into the workspace in
/// editor mode (skipping the chat-mode default).
Future<void> tapEditOnCharacterTile(
  WidgetTester tester,
  String name,
) async {
  await tester.tap(
    find.descendant(
      of: findCharacterTile(name),
      matching: find.widgetWithIcon(IconButton, Icons.edit),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// Closes the Android IME soft keyboard. On a real device, `tester.enterText`
/// opens the IME which then occludes the bottom of the app — `tester.tap`
/// on a button below that fold hit-tests onto the keyboard overlay and
/// silently misses. Unfocusing the primary focus + pumping dismisses the
/// IME and shrinks the viewInsets so the button becomes tappable.
Future<void> dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

/// Waits until the app is fully ready for interaction. Two-phase:
/// 1. `MultiProvider` mounts — `app.main()` returns immediately but
///    services initialize asynchronously in `_MyAppBootState._initServices`;
///    during that window `MyAppBoot` renders a bare `MaterialApp` with no
///    providers above it (see `main.dart`'s `!_initialized` branch). A
///    test that reads a provider before `MultiProvider` mounts will throw
///    `ProviderNotFoundException`.
/// 2. If a provider was seeded (recovery file present at boot), wait for
///    the recovery rebuild to finish fetching models and assigning
///    default domain presets — otherwise the chat path has no model to
///    call. Detected by the presence of any provider + that provider
///    having a non-empty `models` list.
Future<void> awaitAppReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 75),
}) async {
  final deadline = DateTime.now().add(timeout);
  final settings = SettingsService();

  // Phase 1: provider tree mounted.
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(find.byType(MultiProvider))) break;
  }
  if (!tester.any(find.byType(MultiProvider))) {
    fail('MultiProvider never mounted within ${timeout.inSeconds}s');
  }

  // Phase 2: if a provider was seeded, wait for models to populate.
  // Unseeded paths (settings round-trip, onboarding walkthrough) have
  // no providerConfigs — skip the wait.
  final hadSeededProvider = settings.settings.providerConfigs.isNotEmpty;
  if (!hadSeededProvider) {
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    return;
  }

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    final profiles = settings.settings.providerConfigs;
    final hasModels = profiles.isNotEmpty && profiles.first.models.isNotEmpty;
    if (hasModels && !settings.isLoading) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      return;
    }
  }
  fail(
    'Provider models not populated within ${timeout.inSeconds}s — '
    'check the Grok key and network reachability.',
  );
}

/// Waits until the character grid has loaded at least one card. Guards against
/// taps firing before `CharacterService` finishes its initial scan of the
/// cards path — without this, `findCharacterTile(kCassName)` would
/// throw on an empty grid.
Future<void> awaitGridReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  final characterService = tester
      .element(find.byType(MaterialApp))
      .read<CharacterService>();
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (!characterService.isLoading &&
        tester.any(find.byType(CharacterGridItem))) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      return;
    }
  }
  fail(
    'Character grid did not render any cards within '
    '${timeout.inSeconds}s',
  );
}

/// Waits until the chat controller has stopped generating and the last
/// message is an AI turn (assistant or character). Used after `sendMessage`
/// / `generateReply` to block until the reply has fully arrived — regular
/// `pumpAndSettle` does not wait for in-flight HTTP.
Future<void> awaitChatIdle(
  WidgetTester tester, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    final chatContext = tester.element(find.byType(ChatView));
    final controller = chatContext.read<BaseChatViewController>();
    if (!controller.isGenerating && controller.messages.isNotEmpty) {
      final last = controller.messages.last;
      if (last.role == ChatRoleEnum.assistant ||
          last.role == ChatRoleEnum.character) {
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        return;
      }
    }
  }
  fail('Chat controller still generating after ${timeout.inSeconds}s');
}
