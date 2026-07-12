# Cardwave — Bug & UX Findings (for Opus to fix)

Reviewed by Fable, 2026-07-12. Static review + live web UX pass; no code was changed.
Each finding: **Severity** (P0 data-loss/crash, P1 functional bug, P2 UX flaw, P3 polish) · location · problem · fix instruction.
Fix instructions are written to be executed without re-investigation. Verify each fix compiles (`flutter analyze`) and, where noted, add/extend a test.

Status: COMPLETE — full audit. Chunks 1–4, 6, 7 static; chunk 5 live web UX pass. 28 findings: F1–F22 (code), U1–U6 (UX). The "Fix order for Opus" list mid-file predates the later chunks; final order:
1. Error-vs-Exception sweep: F1 + F6 (incl. chunk-7 confirmations) + F12 + **F17** + F21's catch changes + F22.
2. Atomic/serialized writes: F2 + F3 + **F19** (PNG .bak).
3. Exit/background flush: F7 + F8 + F16.
4. Onboarding & first-run: F11, then U1 + U2.
5. Editor safety: **F20** (empty-find guard + undo snapshot) + F21's `finally` restructure.
6. Polish, any order: F4, F5, F9, F10, F13, F14, F15, F18, U3–U6.

## Review coverage

- [x] i18n / locale switching / pluralization (recent work)
- [x] Settings persistence & bootstrap (settings_service, settings_repository, app_bootstrapper, storage layer)
- [x] Chat & group persistence (chat_repository, io_chat, io_group)
- [x] Chat & async controllers (lifecycle, races, dispose)
- [x] Settings / LLM providers / secrets
- [x] Onboarding flow
- [x] Media controllers (TTS, video), character_service save paths, grid filter controller (second pass, chunk 4)
- [x] Live UX pass: onboarding, language switch, home grid, workspace, no-provider flows, mobile viewport (chunk 5)
- [x] LLM execution pipeline (chat_execution_service, tool loop), full group_chat_controller, speaker selection, web storage backend (third pass, chunk 6)
- [x] Character data path (io_character PNG writes, character_repository, library scan), editor (find/replace, content cleaner, AI diff, lorebook), image-generation mixin, search service, taxonomy/memory/nodes/group repositories, workspace controller (fourth pass, chunk 7)

Every area of lib/ has now been audited. Not audited: the packages/ internals (cardwave_llm, cardwave_embeddings, cardwave_memory, cardwave_nodes, cardwave_retrieval) beyond their call surfaces, and the "Coverage notes" section mid-file is superseded by this list.

---

## Chunk 1 — Bootstrap, settings persistence, i18n core

### F1 · P0 · Corrupt data during init bricks the app on a blank splash (Error vs Exception catch gap)

- **Where:** [lib/main.dart](lib/main.dart) `_initServices` (`on Exception catch` at the end, ~line 466); same pattern in [lib/settings/src/repositories/settings_repository.dart:56](lib/settings/src/repositories/settings_repository.dart#L56) `loadSettings`, and `loadRecovery`.
- **Problem:** All init-path catches use `on Exception`. Corrupt/unexpected JSON produces `TypeError` (e.g. `jsonDecode(content) as Map<String, dynamic>` when the file holds a JSON array; bad field types inside `AppSettings.fromJson` casts). `TypeError` is an `Error`, not an `Exception`, so it escapes `loadSettings`'s catch, escapes `_initServices`'s catch, and because `_initServices` is called `unawaited(...)`, becomes an unhandled async error. Result: `_initialized` and `_error` both stay unset → the user sees an empty scaffold (blank screen) forever, with no message. Same gap exists for any `Error` thrown by any of the ~40 service constructors/inits in `_initServices`.
- **Fix instruction:**
  1. In `_initServices`, change the final `on Exception catch (e, stack)` to a plain `catch (e, stack)` (catches `Error` too — at top-level bootstrap this is correct; rethrow nothing, show the existing error screen).
  2. In `SettingsRepository.loadSettings` and `loadRecovery`, replace `on Exception catch` with plain `catch` so a corrupt file degrades to `{}` / `null` (fresh-defaults path) instead of throwing `TypeError` upward. Keep the log lines.
  3. Add a test: write a settings.json containing `[1,2,3]` and assert `loadSettings()` returns `{}`.

### F2 · P1 · Settings/recovery writes are non-atomic — crash mid-write destroys settings.json

- **Where:** [packages/cardwave_storage/lib/src/app_storage_windows.dart:96](packages/cardwave_storage/lib/src/app_storage_windows.dart#L96) `writeString` (and `writeBytes`, line 81).
- **Problem:** `file.writeAsString(content)` truncates then writes in place. A crash, power loss, or OS kill mid-write leaves a truncated/empty settings.json (or chat/group JSON — every domain funnels through this method). On next launch the decode fails → settings silently reset (providers survive only via the recovery mirror; theme, locale, personas, presets, drawer state are lost). For chat files this is unrecoverable message loss.
- **Fix instruction:** In `AppStorageWindows.writeString`/`writeBytes`, write to `<path>.tmp` first, `flush: true`, then `await tmpFile.rename(path)` (atomic on the same volume on Windows/Android). Delete a stale `.tmp` if rename fails. Mirror in the web implementation only if applicable (IndexedDB/localStorage writes are already atomic — check `app_storage_web.dart` and leave it alone if so).

### F3 · P1 · Concurrent unserialized saves of settings.json (three writers can interleave at startup)

- **Where:** [lib/settings/src/services/settings_service.dart:83](lib/settings/src/services/settings_service.dart#L83) `saveSettings`; callers `_populateModelOptionsOnStartup` and `_maybeRunDailyModelRefresh` in [lib/main.dart](lib/main.dart) (both `unawaited`), plus `rebuildFromRecovery` and any user-triggered save.
- **Problem:** Nothing serializes writes to settings.json. At startup up to three async flows call `saveSettings()` concurrently; two overlapping `writeAsString` calls to the same file can interleave (especially before F2 is fixed), producing garbage JSON. Low probability per run, but the app writes settings very often (every drawer toggle).
- **Fix instruction:** Add a simple write-queue to `SettingsService.saveSettings`: a `Future<void> _pending = Future.value();` field, and inside `saveSettings` chain `_pending = _pending.then((_) => _doSave());` returning the new `_pending`. (Do it in `SettingsService`, not in AppStorage, so the last-in-memory-state-wins semantics stay obvious.)

### F4 · P2 · Language picked during onboarding is silently lost if onboarding is abandoned — the guard protecting a phantom crash

- **Where:** [lib/settings/src/services/locale_controller.dart:36-48](lib/settings/src/services/locale_controller.dart#L36-L48) `setLocale`, and its doc comment (lines 28-35).
- **Problem:** `setLocale` skips persistence while `onboardingComplete == false`, citing a `characterPath!` crash in `saveSettings`. That premise is false: `SettingsService.init` line 77 does `_settings.characterPath ??= await getNativeDefaultCharacterPath(...)`, so `characterPath` is never null after init and `saveSettings` cannot crash on it. Consequence of the unnecessary guard: a user who picks a language on the onboarding screen and quits before finishing gets English (or device locale) back on next launch — confusing on a first-run flow, which is exactly where non-English users set their language.
- **Fix instruction:** Delete the `if (settingsService.settings.onboardingComplete)` guard in `setLocale` (always `unawaited(settingsService.saveSettings())`), and rewrite the doc comment (drop the phantom-crash paragraph). Note `_populateModelOptionsOnStartup` in main.dart already calls `saveSettings()` unconditionally pre-onboarding, confirming it's safe.

### F5 · P3 · `Logger.root.level = Level.ALL` unconditionally

- **Where:** [lib/main.dart:164](lib/main.dart#L164).
- **Problem:** Release builds process every log record at ALL level app-lifetime; the listener filters by logger name only after the record is built. Minor perf/battery cost on Android.
- **Fix instruction:** Set `Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;` (keep listener unchanged).

*(Checked and found OK: plural-resolver CLDR rules for ja/zh/ko/pt/hi; slang live-switch wiring — `TranslationProvider` above `MaterialApp`, `locale:` from `TranslationProvider.of(context)`; language picker dialog; recovery-rebuild flow ordering; `_freshReset` env parsing.)*

---

## Chunk 2 — Chat/group persistence & controllers

### F6 · P1 · One corrupt session.json aborts the entire chat-index rebuild (same Error-vs-Exception gap as F1)

- **Where:** [lib/chat/src/repositories/io_chat.dart:91](lib/chat/src/repositories/io_chat.dart#L91) (per-file catch in `_rebuildIndex`), [io_chat.dart:45](lib/chat/src/repositories/io_chat.dart#L45) (`getChatIndex`), [io_chat.dart:130](lib/chat/src/repositories/io_chat.dart#L130) (`getChat`). Audit [lib/group/src/repositories/io_group.dart](lib/group/src/repositories/io_group.dart), [lib/memory/src/repositories/io_memory.dart](lib/memory/src/repositories/io_memory.dart), [lib/nodes/src/repositories/io_nodes.dart](lib/nodes/src/repositories/io_nodes.dart), [lib/character/src/repositories/io_character.dart](lib/character/src/repositories/io_character.dart) for the identical pattern.
- **Problem:** `_parseChatSession` does `jsonDecode(content) as Map<String, dynamic>` + `ChatSession.fromJson`. A structurally-wrong file (truncated write from F2, valid JSON of the wrong shape, bad field type) throws `TypeError`, which `on Exception catch` does not catch. In `_rebuildIndex` that error escapes the per-file closure, rejects the `Future.wait`, and the whole rebuild throws — so ONE bad session file makes the character's entire chat list unloadable, when the code's clear intent (log + `return null`) was to skip just that file.
- **Fix instruction:** In every per-file/per-entry load catch in the repositories listed above, change `on Exception catch` to plain `catch (e, stackTrace)`. Keep the existing log calls. Do NOT change catches around writes.

### F7 · P1 · Closing the desktop window can lose the last ~500ms of chat (debounced saves never awaited on exit)

- **Where:** [lib/chat/src/services/chat_service.dart:31-43](lib/chat/src/services/chat_service.dart#L31-L43) (`AppLifecycleListener`) and `_flushPendingSaves` (line 68).
- **Problem:** Chat saves are debounced 500ms (`updateChat`, line 290). The lifecycle listener flushes on paused/hidden/detached, but `_flushPendingSaves` fires the saves with `unawaited(...)` — on Windows/Linux desktop, closing the window tears the process down without waiting for those async file writes, and there is no `onExitRequested` handler anywhere in the app (verified by grep). The most recent message edit / streamed reply can be lost on window close. On Android the paused-state flush usually completes, so this is primarily a desktop bug.
- **Fix instruction:** (1) Make `_flushPendingSaves` return `Future<void>` that `Future.wait`s the `saveChat` calls. (2) Add `onExitRequested: () async { await _flushPendingSaves(); await GroupChatService-flush-too (see F8); return AppExitResponse.exit; }` to the `AppLifecycleListener`. Keep the sync fire-and-forget behavior for the paused/hidden path (mobile) but await it in `onExitRequested`.

### F8 · P2 · Group chats have no background-flush at all — weaker than 1:1

- **Where:** [lib/group/src/services/group_chat_service.dart:26](lib/group/src/services/group_chat_service.dart#L26) (`_pendingSaves`).
- **Problem:** `GroupChatService` copies `ChatService`'s 500ms debounce but not its `AppLifecycleListener` flush or `dispose` flush. Backgrounding on Android (process kill) or closing the desktop window inside the debounce window loses the pending group-chat save. `GroupChatController` flushes on its own dispose (line ~519), which covers normal navigation but not app exit while the chat is open.
- **Fix instruction:** Mirror the `ChatService` pattern in `GroupChatService`: store `(groupId, session)` alongside the `Timer` in `_pendingSaves` (a small record class), add an `AppLifecycleListener` that flushes on paused/hidden/detached, flush in an overridden `dispose()`, and hook into the same `onExitRequested` as F7.

### F9 · P3 · 1:1 `regenerateLastMessage`/`sendMessage` lack the `isGenerating` guard the group controller has

- **Where:** [lib/chat/src/controllers/chat_controller.dart:300](lib/chat/src/controllers/chat_controller.dart#L300) (`regenerateLastMessage`), [chat_controller.dart:262](lib/chat/src/controllers/chat_controller.dart#L262) (`sendMessage`, non-empty-input path). Compare [group_chat_controller.dart:866](lib/group/src/controllers/group_chat_controller.dart#L866) which guards `isGenerating`.
- **Problem:** The UI disables these actions while generating (message_swipe_flipper/actions_row check `!isGenerating`), so this is currently unreachable through normal taps — but any new call site (keyboard shortcut, swipe gesture, test) can start two concurrent `_generateReply` runs on the same session, corrupting the message list. Cheap defense.
- **Fix instruction:** Add `if (isGenerating) return;` at the top of `regenerateLastMessage`, and in `sendMessage` before appending the user message (mirror the group controller's guards).

### F10 · P3 · `chats.index` read-modify-write races between concurrent debounced saves

- **Where:** [lib/chat/src/repositories/io_chat.dart:180-207](lib/chat/src/repositories/io_chat.dart#L180-L207) (`saveChat` index update).
- **Problem:** Two sessions saving near-simultaneously (e.g. group + 1:1, or TTS/video sidecar completion) both read `chats.index`, modify, and write; the later write silently drops the earlier one's entry update. Self-healing (index rebuilds when stale/corrupt), so P3 — but the rebuild is O(all sessions) I/O.
- **Fix instruction:** Serialize `saveChat`/`deleteChat` index updates with the same chained-future queue pattern as F3, keyed per `chatDirectoryPath`, inside `IOChat`.

*(Checked and found OK: `saveChat`'s transient-message strip/restore around `toJson()`; generation `finally` block cleanup in chat_controller (spinner, empty-bubble removal, swipe rollback); `deleteChat` cancel-pending logic; guarded `.last`/`.first` accesses across chat/group controllers; `improveInput` cancel/restore flow; no `firstWhere` without `orElse` anywhere in lib/.)*

---

## Chunk 3 — Onboarding & providers

### F11 · P1 · Failed finish-onboarding leaves a half-added provider; retry duplicates it

- **Where:** [lib/onboarding/src/controllers/onboarding_controller.dart:209-261](lib/onboarding/src/controllers/onboarding_controller.dart#L209-L261) `finishOnboarding`; caller [lib/onboarding/src/pages/onboarding_page.dart:64-77](lib/onboarding/src/pages/onboarding_page.dart#L64-L77).
- **Problem:** `finishOnboarding` does `settings.providerConfigs.add(profile)` and THEN awaits `refreshProviderModels` (a network call). If the fetch throws (flaky network at the exact moment the user taps Finish), the page catches, shows a snackbar, and stays on onboarding — but the profile is already in the in-memory `providerConfigs`. Tapping Finish again adds a SECOND profile with the same API key (new id); the first one persists forever with `models: []` as a phantom broken provider in Settings. Same pattern for `localGgufProfile`.
- **Fix instruction:** Make `finishOnboarding` idempotent: wrap each add+refresh in try/catch and remove the profile from `providerConfigs` on failure before rethrowing, OR (simpler) at the top of `finishOnboarding`, remove any previously-added entries matching `profile.id`s created by this controller instance (store the created ids on the controller). Prefer the try/catch + remove-on-failure variant. Also apply the same guard to the `localGgufProfile` block.

### F12 · P3 · `on Exception` in `_finishOnboarding` page handler (same family as F1)

- **Where:** [lib/onboarding/src/pages/onboarding_page.dart:72](lib/onboarding/src/pages/onboarding_page.dart#L72).
- **Problem:** A `TypeError`/`StateError` inside `finishOnboarding` escapes the `on Exception catch`, leaving the user stuck on onboarding with no snackbar and no log.
- **Fix instruction:** Change to plain `catch (e, stackTrace)`. (When applying F1's sweep, include this file. General rule for Opus: any catch whose purpose is "keep the UI alive / degrade gracefully" should be a plain `catch`; only catches that intend to handle a specific failure should name a type.)

### F13 · P3 · API keys stored in plaintext twice (settings.json + recovery mirror)

- **Where:** [lib/settings/src/services/settings_service.dart:83-100](lib/settings/src/services/settings_service.dart#L83-L100); recovery model [lib/settings/src/models/llm_providers_recovery.dart](lib/settings/src/models/llm_providers_recovery.dart).
- **Problem:** Provider API keys are written verbatim to two JSON files in app-data. Acceptable for a local desktop app, but the duplication doubles exposure (backup tools, support bundles, users sharing their settings folder to debug). Not urgent; do not switch to flutter_secure_storage without a migration plan (Web/Windows/Android all differ).
- **Fix instruction (minimal):** Add a note to SECURITY.md documenting where keys live on disk. Optionally exclude the recovery mirror from any future "export settings" / diagnostics feature. No code change required now.

### F14 · P3 · Persona name persisted untrimmed

- **Where:** [lib/onboarding/src/controllers/onboarding_controller.dart:257](lib/onboarding/src/controllers/onboarding_controller.dart#L257).
- **Problem:** `canFinish` gates on `personaName.trim().isNotEmpty` but the assignment stores the untrimmed value; a name like `"Sam "` flows into prompt placeholder substitution (`%USER_NAME%`) with a trailing space.
- **Fix instruction:** `settingsService.settings.activePersona.name = personaName.trim();`

*(Checked and found OK: onboarding step navigation and storage-step skip logic on web/mobile; API-key→provider auto-detect + debounced model fetch with cancel-on-dispose; `fetchModels` state machine incl. ZDR toggle; language pick during onboarding persisting via `finishOnboarding`'s save (modulo F4); image_thumbnail stream subscription lifecycle; only 4 raw `.listen(` sites in lib/, all managed.)*

---

## Fix order for Opus

1. **F1 + F6 + F12** (one sweep: Error-vs-Exception catch policy) — highest crash/bug payoff, mechanical.
2. **F2** (atomic writes) then **F3** (serialized settings saves) — data-loss prevention, small diffs.
3. **F7 + F8** (exit/background flush, desktop `onExitRequested`) — chat data loss.
4. **F11** (onboarding idempotency) — first-run reliability.
5. **F4, F5, F9, F10, F13, F14** — cheap polish, any order.

After 1–3, run `flutter analyze` and the existing test suite; add the F1 corrupt-settings test and, if cheap, a corrupt-session-file test for F6 (write a session.json containing `[]`, assert the index rebuild skips it and still returns the other sessions).

## Coverage notes (what was NOT reviewed)

Reviewed in depth: bootstrap (`main.dart`), settings service/repository/storage layer, locale/i18n core, io_chat, chat_service, chat_controller (generation finally-block, send/regenerate/continue), group_chat_service, group_chat_controller (spot), base_chat_view_controller, onboarding controller+page, language pickers.

Not reviewed (time-boxed): editor feature, grid/filter controllers, workspace, search/embeddings, memory & nodes engines, TTS/video/image generation controllers, markdown cache, app_storage_web.dart, packages/ other than cardwave_storage, all UI layout/UX polish (a live UX pass was deliberately deferred). If bugs are reported in those areas, they are unaudited — start fresh there.

---

## Chunk 4 — Additional static findings (second pass)

### F15 · P3 · Every character PNG save nukes the entire Flutter image cache

- **Where:** [lib/character/src/services/character_service.dart:458-459](lib/character/src/services/character_service.dart#L458-L459) (`saveJsonInCacheAndPngNow`).
- **Problem:** `PaintingBinding.instance.imageCache.clear()` + `clearLiveImages()` after each PNG write evicts every decoded image app-wide — all grid thumbnails, chat avatars, and backgrounds re-decode, causing a visible flicker/jank spike after each editor save. Only the saved card's image actually changed.
- **Fix instruction:** Replace the global clear with targeted eviction of the saved card's image provider(s) (e.g. `FileImage(File(absolutePath)).evict()` for the card PNG and its thumbnail path; on web, the memory-image key used by the thumbnail widget). If targeted eviction is impractical for the custom provider, keep the global clear but only when the PNG path actually changed.

### F16 · P2 · Character dirty-flush has the same exit hole as chats (extends F7)

- **Where:** [lib/character/src/services/character_service.dart:86-95](lib/character/src/services/character_service.dart#L86-L95) — `AppLifecycleListener` calls `unawaited(_flushDirtyFilesToPng())`.
- **Problem:** Same class of bug as F7: on desktop window close the process can exit before the async PNG flush finishes; unsaved card edits within the 1s debounce window are lost (JSON cache save is also debounced, `queueJsonInCacheDebounced`).
- **Fix instruction:** Include `CharacterService._flushDirtyFilesToPng()` (awaited) in the `onExitRequested` handler added for F7. No other change needed — the paused/hidden path can stay fire-and-forget.

---

## Chunk 5 — Live UX pass (web build, fresh profile, desktop 2000px + mobile 390px)

Verified working end-to-end (no findings): onboarding language picker switches the whole UI live and persists across reload; onboarding finish → home grid; disclaimer gate on Finish Setup; no-provider warning banner; mobile layouts of grid and workspace adapt cleanly; zero browser-console errors during the entire session.

### U1 · P2 · With no AI provider, "New chat" silently does nothing and the empty state gives wrong guidance

- **Where:** [lib/chat/src/controllers/chat_page_controller.dart:167-183](lib/chat/src/controllers/chat_page_controller.dart#L167-L183) (`createNewChat` null branch = bare `notifyListeners()`); the workspace empty-state widget that renders the "Select a chat to start messaging" text (find it via the `chat.selectChatPrompt`-style key in lib/i18n/en/*.i18n.json).
- **Repro:** Fresh install, skip API key in onboarding → open the bundled assistant card → workspace shows "Select a chat to start messaging" (there are zero chats and no visible way to create one — "New chat" is behind the unlabeled hamburger end-drawer) → drawer → "New chat" → nothing happens: no chat, no snackbar, no log.
- **Fix instruction:** (1) In `createNewChat`, when `newChat == null`, show a snackbar via `NavigationService().showSnackBar(...)` with a localized "Connect an AI provider first" string (add key to all 10 locale files; EN: "Connect an AI provider to start chatting."). (2) In the workspace empty state, when `settingsService.settings.domainPresetIds.isEmpty`, replace the "Select a chat" text with that same message plus a button that opens the provider setup; when presets exist but no chats do, show a "New chat" button instead of only the hint text. This is the single worst first-run moment — the user's very first click dead-ends.

### U2 · P2 · "Configure now" banner reopens full onboarding and forces re-accepting the disclaimer

- **Where:** the banner's "Настроить сейчас" action (grep for the `connectProvider`/banner widget rendering `t.*configureNow`-style key); it routes to the onboarding page.
- **Repro:** After onboarding (disclaimer already accepted), click "Configure now" in the red banner → lands on the full "Quick Setup" screen: persona name shown again, disclaimer checkbox EMPTY again, button reads "Finish Setup" and is disabled until the user re-checks a disclaimer they already accepted.
- **Fix instruction:** Point the banner action at the Settings provider-add dialog (`dialog_provider_config.dart` flow) instead of the onboarding route. If reusing onboarding is deliberate, pre-check (or hide) the disclaimer checkbox when `settings` already records acceptance, prefill persona, and relabel the button ("Save"). Note this flow also re-runs `finishOnboarding` — F11's idempotency fix is a prerequisite.

### U3 · P3 · Onboarding/setup form stretches full-width on desktop

- **Where:** onboarding page layout ([lib/onboarding/src/pages/onboarding_page.dart](lib/onboarding/src/pages/onboarding_page.dart)).
- **Problem:** At desktop widths the API-key and name fields span the entire window (~2000px text fields), which reads poorly and looks unfinished.
- **Fix instruction:** Wrap the form column in `Center` + `ConstrainedBox(constraints: BoxConstraints(maxWidth: 640))`.

### U4 · P3 · Sort dropdown truncates localized labels ("Импортировано ↓" → "Импортир…")

- **Where:** [lib/grid/src/pages/widgets/character_grid_filters.dart:50-51](lib/grid/src/pages/widgets/character_grid_filters.dart#L50-L51) — `ConstrainedBox(maxWidth: 140)`.
- **Problem:** 140px fits English but truncates Russian/Portuguese/Spanish sort labels even when horizontal space is plentiful; truncated with ellipsis on both desktop and mobile.
- **Fix instruction:** Raise to ~200 on wide layouts (e.g. pick 140/200 from a `LayoutBuilder` width check), or drop the arrow glyph from labels and keep them short in all locales.

### U5 · P3 · A11y: key controls lack semantic labels

- **Where:** onboarding disclaimer checkbox (renders as unlabeled `checkbox` in the semantics tree — label text is a separate node); workspace end-drawer hamburger button (unlabeled `button`); grid-item favorite/edit buttons (unlabeled).
- **Fix instruction:** Onboarding: wrap the checkbox+text in `CheckboxListTile` (or `MergeSemantics`) so the semantic node carries "I have read and agree to the Disclaimer". Drawer button: add `tooltip:`/`Semantics(label:)` "Chat options". Grid-item icon buttons: add `tooltip:`s (they double as semantics labels).

### U6 · P3 · Card-count pill reads as an "active filters" badge

- **Where:** `_CountPill` in [lib/grid/src/pages/widgets/character_grid_filters.dart:101-106](lib/grid/src/pages/widgets/character_grid_filters.dart#L101-L106).
- **Problem:** On a fresh install the pill shows a bare "1" in a circle directly next to the filter (tune) icon — it reads as "1 filter active", not "1 card". (I misread it exactly that way during the pass.)
- **Fix instruction:** When no filter is active, render "N" with a subtle "cards" tooltip AND move the pill left of the tune icon, or always render "filtered/total" ("1/1") so it can't be read as a filter count. Cheapest: add `Tooltip(message: t.grid.filters.cardCountTooltip)`.

---

## Chunk 6 — LLM execution pipeline, group controller, web storage (third pass)

### F17 · P1 · An `Error` inside the generation pipeline makes replies vanish silently (worst instance of the F1 family)

- **Where:** [lib/chat/src/services/chat_execution_service.dart:454](lib/chat/src/services/chat_execution_service.dart#L454) and [:560](lib/chat/src/services/chat_execution_service.dart#L560) — `on Exception catch (e) { streamController.addError(e); }`.
- **Problem:** The entire generate-reply flow runs in an async closure. `on Exception` misses `Error`s (a stale `modelPresetId` hitting a null-assert or cast in `resolvePreset`/`createRunner`, a `StateError` from a provider SDK). When one throws: the catch is skipped, `finally` still closes the stream cleanly, the controller's `await for` ends as if the model returned nothing, and the empty bubble is dropped. Net effect: the user hits Send and *nothing happens* — no reply, no snackbar, no visible error. This is more insidious than F1's stuck splash because it looks like the app just ignored the user.
- **Fix instruction:** In both closures change to plain `catch (e, st)` and call `streamController.addError(e, st)` (also fixes the currently-missing stack trace on the existing path). While in the F1 sweep, also convert the generation-path catches in [chat_controller.dart:623](lib/chat/src/controllers/chat_controller.dart#L623) and [group_chat_controller.dart:764](lib/group/src/controllers/group_chat_controller.dart#L764) to plain `catch` — their `finally` blocks already handle cleanup correctly, but the snackbar/log in the catch must fire for `Error`s too.

### F18 · P3 · Group auto-chat loops forever doing nothing when no speaker is selectable

- **Where:** [lib/group/src/controllers/group_chat_controller.dart:542-554](lib/group/src/controllers/group_chat_controller.dart#L542-L554) (`startAutoChat`); `_generateNextCharacterTurn` returns silently when `selectNextSpeaker` yields null (line 580).
- **Problem:** With every member muted (or members removed mid-loop), `selectNextSpeaker` returns null each iteration, but the loop keeps running — the auto-chat button stays in its active state while nothing is generated, and with `autoChatDelaySeconds` at 0 the loop spins without any wait at all. The user gets no explanation.
- **Fix instruction:** Make `_generateNextCharacterTurn` return `bool` (`false` when no speaker was selected). In `startAutoChat`, on `false`: call `stopAutoChat()`, `NavigationService().showSnackBar(...)` with a localized "No available speakers — everyone is muted." string (add key to the 10 locale files), and `break`.

*(Checked and found OK, chunk 6: tool-loop iteration bound + per-turn call caps + side-effect-only termination logic; cancel handling at all three loop exit points; local-GGUF VRAM eviction + context-size clamping; group per-turn session copy with prefixed history (regen/continue exclusion correct); speaker selection (round-robin wrap, talkativeness weighting, whole-word mention regex with short-name guard); group controller dispose flushes the debounced save; `app_storage_web.dart` — IndexedDB writes are transactional, so F2's temp+rename fix should NOT be applied there (confirming F2's note); `AppStorageWeb.init` throwing `UnsupportedError` on browsers without IndexedDB is caught once F1's plain-catch fix lands in `_initServices`.)*
---

## Chunk 7 — Character data path, editor, image mixin, search, remaining repositories (fourth pass)

### F19 · P1 · The user's card PNG is overwritten in place, non-atomically — a crash can destroy irreplaceable artwork

- **Where:** [lib/character/src/repositories/io_character.dart:359-378](lib/character/src/repositories/io_character.dart#L359-L378) `_saveJsonInPNG` and [:404-414](lib/character/src/repositories/io_character.dart#L404-L414) `replaceCharacterImage`.
- **Problem:** Keystroke edits only touch the debounced JSON cache sidecar; the PNG is rewritten on flush triggers (navigating away from the editor, app backgrounding, explicit "Overwrite PNG") when the card is dirty. Each such flush reads the user's card PNG, re-embeds the JSON chunk, and writes the result back **to the same path** with the non-atomic `writeBytes` (F2). The PNG is the user's primary artifact — often the only copy of the artwork — and the backgrounding trigger fires exactly when the OS is most likely to kill the process mid-write. A crash/power-loss mid-write truncates it; unlike settings.json there is no recovery mirror.
- **Fix instruction:** F2's temp+rename fix covers the atomicity. Additionally, in `_saveJsonInPNG` only: before the write, copy the current PNG to `<path>.bak` (overwriting the previous .bak), so even a bug in the embed logic (not just a torn write) can be recovered by the user. Exclude `*.bak` from `scanValidCardStats` (it already filters to `.png` extensions, so a `.bak` suffix is automatically excluded — verify with a test).

### F20 · P1 · Find/replace with an empty "Find" field shreds the entire card, with no undo anywhere in the editor

- **Where:** [lib/editor/src/pages/widgets/dialog_find_replace.dart:81-89](lib/editor/src/pages/widgets/dialog_find_replace.dart#L81-L89); applied via `applyCleaner` → [character_card_v3.dart:232](lib/character/src/models/character_card_v3.dart#L232) `transformAllStrings`.
- **Problem:** The Replace All button builds `(text) => text.replaceAll(_findController.text, _replaceController.text)` with no validation. In Dart, `replaceAll('', r)` inserts `r` **between every character** (`'ab'.replaceAll('', 'X')` → `'XaXbX'`). An accidental tap with an empty Find field therefore corrupts every string on the card — name, description, tags, lorebook keys/contents, greetings — the generic confirm dialog does not hint at this, the editor has **no undo** (verified: no undo/snapshot/backup code in lib/editor), and the damage autosaves within 1s (`_triggerJsonCacheAutoSave`) and reaches the PNG on navigation.
- **Fix instruction:** (1) In `_DialogFindReplaceState`, disable Replace All while `_findController.text.isEmpty` (ValueListenableBuilder on the controller). (2) In `EditorViewState.applyCleaner` ([editor_view.dart:75](lib/editor/src/pages/widgets/editor_view.dart#L75)), before `transformAllStrings`, snapshot `jsonEncode(widget.characterFile.card.toJson())`; after applying, show a snackbar with an Undo action that restores via `CharacterCardV3.fromJson` + `_editorVersion++` + autosave. This one snapshot covers find/replace AND all content-cleaner actions, since both funnel through `applyCleaner`.

### F21 · P2 · An `Error` during image generation permanently disables the feature for the session (missing `finally`)

- **Where:** [lib/chat/src/controllers/mixins/chat_image_generation_mixin.dart:95-298](lib/chat/src/controllers/mixins/chat_image_generation_mixin.dart#L95-L298) `generateImage`.
- **Problem:** `_isGeneratingImage = false` is only reset on the success path and inside `on Exception catch`. An `Error` escaping (`TypeError` from a malformed provider response in `buildImagePrompt`, etc.) leaves `_isGeneratingImage == true` forever — every subsequent `generateImage` silently returns `false` at the top guard until app restart — and the placeholder bubble spins permanently on "Preparing image prompt…". F1-family, but with sticky state damage.
- **Fix instruction:** Restructure `generateImage` with a `finally` that does `_isGeneratingImage = false; notifyListeners();`, remove those lines from the success/catch paths, and change `on Exception catch` to plain `catch (e, st)` (keep the placeholder-removal and snackbar logic in the catch). Also change the `resolvePreset` catch at line 153 to plain `catch`.

### F22 · P2 · Corrupt taxonomy file breaks bootstrap instead of falling back to the bundled asset

- **Where:** [lib/character/src/repositories/taxonomy_repository.dart:34-50](lib/character/src/repositories/taxonomy_repository.dart#L34-L50) `init` / `hydrateFromJson`.
- **Problem:** `hydrateFromJson` casts (`jsonDecode(raw) as Map<String, dynamic>`, `TaxonomyData.fromJson`) throw `TypeError` on a structurally-corrupt user taxonomy file; `on Exception` misses it, so `init()` throws into `_initServices` → (pre-F1) blank splash / (post-F1) full error screen. Either way the app dies over a file that has a perfectly good bundled fallback sitting in assets.
- **Fix instruction:** In `TaxonomyRepository.init`, change to plain `catch`, and when the failed source was the user file (`exists == true`), retry once with `rootBundle.loadString(AppConstants.taxonomyAssetPath)` before giving up. Keep the error log.

**F6 audit-list confirmation:** the identical `on Exception`-around-`jsonDecode`/`fromJson` load pattern is now verified present at [io_group.dart:43](lib/group/src/repositories/io_group.dart#L43) and [:88](lib/group/src/repositories/io_group.dart#L88), [io_memory.dart:42](lib/memory/src/repositories/io_memory.dart#L42), [io_nodes.dart:41](lib/nodes/src/repositories/io_nodes.dart#L41). Include all four in F6's plain-catch sweep.

*(Checked and found OK, chunk 7: `scanLibrary` diff/upsert flow with per-card `on Object` isolation (correct there); `readCharacter` typed-catch + rethrow chain; import/clone name-dedup loops; thumbnail generation serialization via chained futures; `createCharacter` filename sanitization; content-cleaner/find-replace confirm dialogs (mechanism fine — the gap is validation+undo, see F20); AI global-action propose→diff→confirm flow incl. cancellation; `SearchService` end to end — hash-based change detection, queue drain, per-field failure isolation, coalesced notify, disposal guards; `WorkspaceController` (trivial, correct); image mixin's review gating, cancel handling, and read/write/other tool-call bucketing with order-preserving result reassembly.)*
