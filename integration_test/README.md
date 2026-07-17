# Integration tests

UI-driven smoke tests that run the real app on an Android emulator and hit real provider APIs (Grok / xAI). Each test covers one happy-path flow with the minimum API calls needed to verify the network + UI wiring.

## Prerequisites

- Android Studio installed with an SDK 34 image (Google APIs, x86_64).
- An AVD (tested with Pixel 6, Android 14 / UpsideDownCake).
- Hardware virtualization enabled:
  - Windows: Windows Hypervisor Platform feature turned on.
  - BIOS/UEFI: Intel VT-x / AMD-V enabled.
- An xAI API key — [x.ai developer console](https://x.ai) → create key. Starts with `xai-`.
- (Optional) A NanoGPT API key — needed only for `media_config_fallback_test.dart`. Starts with `sk-nano-`. The wrapper scripts forward it via `--dart-define=NANOGPT_API_KEY=...` automatically when it's set in `.test_secrets`.

## Running

Start the emulator first:

```
flutter emulators --launch Pixel_6
```

Wait for it to boot (check with `flutter devices`; it should show `emulator-5554` as `mobile`).

Run the full default suite:

```
flutter test integration_test/ -d emulator-5554 --dart-define=GROK_API_KEY=xai-...
```

Run a single test:

```
flutter test integration_test/chat_one_to_one_test.dart -d emulator-5554 --dart-define=GROK_API_KEY=xai-...
```

Enable the video test (opt-in; ~$0.10–0.50 per run):

```
flutter test integration_test/video_generation_test.dart -d emulator-5554 --dart-define=GROK_API_KEY=xai-... --dart-define=RUN_VIDEO=true
```

Without `GROK_API_KEY`, tests that need the network will skip with a clear message. `settings_round_trip_test.dart` runs regardless (no network).

### Video playback on the emulator

The video test asserts the data pipeline (submit → poll → download → save → `VideoJobState.done`), not on-screen rendering. Android emulators don't expose hardware video codecs the way real devices do, and `media_kit` falls back to software rendering — playback typically shows a **black rectangle even though the mp4 file is valid**. Look for these lines in the test log to confirm S/W fallback:

```
media_kit: Emulator detected.
media_kit: Enforcing S/W rendering.
```

To verify the file is actually a playable video, pull it off the emulator and open in VLC:

```
adb pull /data/data/com.example.cardwave/files/.cache_cardwave_dev/characters/Test_Character/chats/<chat-id>/video/vid_*.mp4
```

Or run the test on a real device — `flutter test integration_test/video_generation_test.dart -d <device-id>`.

## Tests

| File | Covers | Cost |
|---|---|---|
| `settings_round_trip_test.dart` | JSON persistence end-to-end, app boots | 0 |
| `onboarding_walkthrough_test.dart` | Type key in onboarding, land on grid | 1 chat |
| `chat_one_to_one_test.dart` | Tap card, send, receive reply | 1 chat |
| `chat_group_test.dart` | Create group, add the seed character, send, receive | 1 chat |
| `tts_test.dart` | Chat reply + TTS play button | 1 chat + 1 TTS |
| `image_generation_test.dart` | Magic wand → free prompt image | 1 image |
| `auto_tag_test.dart` | Grid card popupmenu → Auto-Tag → the seed card's `appCardTags` populated with valid taxonomy IDs (structured-output round-trip) | 1 system-domain LLM call |
| `video_generation_test.dart` | Magic wand → free prompt video (opt-in) | 1 video |
| `media_config_fallback_test.dart` | Stale-preset fallback: pick NanoGPT image preset on session, delete NanoGPT, re-enter chat, image still generates against Grok app default | 1 chat + 1 image (needs NANOGPT_API_KEY) |
| `character_media_config_fallback_test.dart` | Same fallback at the character layer: pick NanoGPT image preset in the editor's Media tab, delete NanoGPT, reopen editor, validator nulls the stale id | 0 (needs NANOGPT_API_KEY) |

## How the bootstrap works

`app_test_helpers.dart`:

- `wipeAppData()` clears `getApplicationDocumentsDirectory()` so each test starts fresh.
- `seedGrokRecovery()` writes `llm-providers-recovery.json` with the Grok key + a character path. The app's `SettingsService.init` finds no `cardwave_settings.json` but a valid recovery file, seeds the Grok provider, and flips `_needsRebuildFromRecovery=true`. `MyApp`'s first-frame callback then fetches Grok models, assigns default domain presets, and saves settings. End state: fully configured app with Grok ready to chat, onboarding skipped. No production code changes.
- `awaitAppReady(tester)` polls `SettingsService.isLoading` since `pumpAndSettle` alone won't wait for in-flight HTTP.
- `grokApiKey` / `runVideo` / `hasGrokKey` are the `--dart-define`-backed flags.

## What's covered beyond day 1

See the plan in `.claude/plans/` for the phased roadmap — harden each smoke with unhappy paths (Phase 2), then editor/lifecycle (Phase 3), workspace surface (Phase 4), lorebook (Phase 5), cross-provider matrix (Phase 6, opt-in only), recovery/migration (Phase 7), web runner (Phase 8), Windows runner (Phase 9), CI (Phase 10).
