# i18n Progress

Live state for `docs/I18N_PLAN.md`. Every executing model updates this file in the same commit
as the work it describes. Conversation context is disposable; this file is not.

## Steps
- [x] Step 1 — Plan (Fable) — done 2026-07-11
- [x] Step 2 — Infrastructure (**Opus**) — done 2026-07-11
- [ ] Step 3 — Extraction (**Sonnet**)
- [ ] Step 4 — Translation + glossary (**Opus**)
- [ ] Step 5 — Error-check + web verification (**Opus**)
- [ ] Step 6 — Optional acceptance (Fable)

## Step 2 checklist (Opus)
- [x] 2.1 branch `feat/i18n` + deps + slang.yaml + locale skeleton files + first generate
- [x] 2.2 `AppSettings.localeTag` + json regen
- [x] 2.3 LocaleController + bootstrap apply
- [x] 2.4 TranslationProvider + all three MaterialApps wired
- [x] 2.5 gear-menu entry + `showLanguageDialog` + `DialogLanguagePicker`
- [x] 2.6 two DateFormat call sites locale-aware
- [x] 2.7 DONE criteria verified on Windows desktop
- es-419 contingency outcome: **`es-419` worked** — slang parsed it as
  `es419(languageCode: 'es', countryCode: '419')`. No fallback to plain `es` needed;
  kept dir `lib/i18n/es-419/`.

### Step 2 notes
- slang resolved to **3.32.0** (not 4.x): the dependency solver is pinned by the existing
  `import_lint 0.1.6` / `analyzer 12.1.0` constraints. 3.32.0 is the latest compatible.
- Generated API confirmed: `LocaleSettings.setLocaleRaw(tag)`, `LocaleSettings.useDeviceLocale()`,
  `LocaleSettings.currentLocale`, `AppLocaleUtils.supportedLocales`,
  `TranslationProvider.of(context).flutterLocale`, global `t`. Import:
  `package:cardwave/i18n/gen/translations.g.dart`.
- 135 skeleton files created (15 namespaces × 9 locales), all `{}` except
  `en/settings.i18n.json` (`gearLanguage`, `languageSystemDefault`).

### Step 2 §2.7 verification results
- `flutter analyze`: clean of new issues. The only reported items are 36
  pre-existing environmental warnings — every `packages/*/analysis_options.yaml`
  includes `../../qcheck/app/lib/*.yaml`, which doesn't resolve in this checkout
  (qcheck sits at `../qcheck`, not `../../qcheck`). Not introduced by this work;
  untouched analysis_options files.
- `dart run slang analyze`: no issues (writes `_missing_translations.json` /
  `_unused_translations.json` — expected: en complete, 8 locales all-missing).
- `flutter test`: 68/68 pass (integration_test excluded).
- Windows desktop **build** succeeds: `√ Built build\windows\x64\runner\Debug\
  cardwave.exe`. (A background `flutter run` couldn't attach a debug connection
  because it was launched detached — a launcher artifact, not a code issue.)
- Language modal confirmed opening + listing languages on the running Windows
  desktop app (manual check by the user).
- Modal contents + switch/persist logic verified with a throwaway widget test
  (now deleted — Step 3 owns permanent tests): exactly 10 rows with keys
  `language-tile-{system,en,ru,pt-BR,es-419,ja,zh-Hans,zh-Hant,ko,hi}`; the
  check mark tracks the active choice; `LocaleController.setLocale` switches the
  live slang locale and writes `localeTag`; `applyPersisted` restores it after a
  simulated relaunch; System-default clears the tag.

### Heads-up for Step 5 (and Step 4)
Step 2 ships **English-only content** by design (all 8 non-en namespaces are
`{}`, `fallback_strategy: base_locale`). So switching to e.g. Русский right now
does **not** visibly change the app's own strings — they fall back to English.
What *does* change on switch: Flutter's `GlobalMaterialLocalizations`-provided
widget chrome and the two locale-aware `DateFormat` call sites. The per-language
visual rendering that §2.7 gestures at ("picking Русский changes chrome") only
becomes observable once Step 4 adds translations; Step 5's Chrome pass across all
9 languages is where that gets verified.

## Step 3 checklist (Sonnet) — one commit per row
- [x] 1 `lib/grid/` → `grid`
- [x] 2 `lib/routing/` → `routing`
- [x] 3 `lib/onboarding/` → `onboarding`
- [x] 4 `lib/common/` → `common`
- [x] 5 `lib/settings/` → `settings`
- [x] 6 `lib/llm_app/` → `llmApp`
- [x] 7 `lib/character/` → `character`
- [x] 8 `lib/chat/` → `chat`
- [x] 9 `lib/editor/` → `editor`
- [x] 10 `lib/group/` → `group`
- [x] 11 `lib/workspace/` → `workspace`
- [x] 12 `lib/nodes/` → `nodes`
- [x] 13 `lib/memory/` + `lib/search/`
- [x] 14 root files → `app`
- [x] 3.7 final leftover sweep done

## Step 4 checklist (Opus) — one commit per language
- [ ] 4.1 Step-3 open questions resolved
- [ ] 4.2 `docs/I18N_GLOSSARY.md` created
- [ ] ru
- [ ] pt-BR
- [ ] es-419 (or es — see Step 2 contingency)
- [ ] ja
- [ ] zh-Hans
- [ ] zh-Hant
- [ ] ko
- [ ] hi
- [ ] 4.5 self-review pass committed
- [ ] 4.6 slang analyze: zero missing / zero unused

## Step 5 checklist (Opus)
- [ ] 5.1 branch diff review + fixes committed
- [ ] 5.2 analyze/test/slang-analyze clean
- [ ] 5.3 web smoke test — results table below
- [ ] persistence check (ru survives page reload)

### 5.3 Web results
| Locale | Renders (no tofu) | No overflow | Console clean | Screenshots |
|---|---|---|---|---|
| en | | | | |
| ru | | | | |
| pt-BR | | | | |
| es-419 | | | | |
| ja | | | | |
| zh-Hans | | | | |
| zh-Hant | | | | |
| ko | | | | |
| hi | | | | |

## Open questions (append; do not delete resolved ones — mark them)
- **[grid] "Cardwave" wordmark** (`lib/grid/src/pages/widgets/app_bar_grid.dart`,
  the `GradientText('Cardwave', ...)` shown when the neon theme is active):
  NOT extracted. §1 of the plan and the Step 4 glossary already decide
  "Cardwave" stays untranslated in every locale, same treatment as the native
  language names excluded in `dialog_language_picker.dart`. Extracting it to a
  key whose value is identically "Cardwave" in all 9 locale files seemed like
  pure overhead with no behavior difference. Resolved (non-action / skip) —
  flagging so Step 4/5 know it was a deliberate call, not a miss.
- **[onboarding] `kHaveLocalGgufExpanderTitle` / `kPickFileLabel`**
  (`lib/onboarding/src/pages/onboarding_page.dart`, the local-GGUF
  expander title and its "Pick GGUF file..." button, both rendered via
  `const Text(kConstant)`): NOT extracted in row 3. Both constants are
  declared in `lib/settings/src/utils/local_gguf_strings.dart` (row 5's
  territory) and are also consumed by
  `lib/settings/src/pages/widgets/dialog_local_gguf_provider_config.dart`.
  Converting them to `t.` keys requires editing the settings source file
  and removing `const` at every call site (including this onboarding
  one) — deferred to row 5 so lib/settings/ isn't touched out of order.
  Row 5: convert both constants to non-const `t.settings.*` getters and
  drop `const` from the two `Text(...)` call sites (here and in
  dialog_local_gguf_provider_config.dart). **Resolved in row 5**: both
  converted to `t.settings.localGguf.*` getters; the onboarding call
  sites had `const` dropped as a ripple (see row 5 entry below).
- **[settings] `dialog_taxonomy_editor.dart`** (~40 strings: dialog
  titles, tooltips, field labels/hints, confirm dialogs): NOT
  extracted, whole file skipped. This is the Taxonomy Tags editor,
  reachable only via a `kDebugMode`-gated menu entry in
  `settings_tab_general.dart` — end users never see it in release
  builds. Matches the plan's "developer surfaces" scope exclusion
  (§1, same category as the Logs screen) more strongly than Logs does,
  since Logs is reachable in production too. The menu entry itself
  ("Taxonomy Tags") IS extracted since it's a settings-menu label, not
  part of the debug tool's own UI.
- **[settings] `ChatTheme` preset names** (`lib/settings/src/models/chat_theme.dart`
  — 11 `static const ChatTheme` fields: 'Azure', 'Cappuccino', 'Celestial
  Macaron', 'Dark Lite', 'Dark V 1.0', 'Glimmer', 'Moonlit Echoes',
  'Cardwave Neon', 'Cardwave Neon (Flat)', plus 'Native Light'/'Native
  Dark' built at runtime): NOT extracted. These names are shown to the
  user in the chat-theme picker (`lib/chat/src/pages/widgets/tile_chat_theme.dart`),
  so they're genuinely in scope — but `ChatTheme.azure` is used as a
  **compile-time-constant default parameter value** in
  `lib/settings/src/models/app_settings.dart` (`this.chatTheme =
  ChatTheme.azure`) and `lib/chat/src/pages/widgets/chat_view.dart`
  (`this.theme = ChatTheme.azure`). Making `.name` a `t.` getter would
  make the whole `ChatTheme` instance non-const, breaking both default
  values — fixing that means restructuring those two call sites
  (nullable param + null-coalescing fallback), which is a model-level
  refactor spanning outside lib/settings/, not mechanical string
  extraction. Flagging for Step 4/5 or a follow-up task; the qcheck
  lint rule Step 6 proposes (flag new hardcoded literals) should also
  catch new theme presets if any are added later.
- **[common] `UtilsApp.timeAgo()` relative-time unit strings**
  (`lib/common/src/utils/utils_app.dart:75-86`): NOT extracted. This
  hand-rolled formatter returns strings like `'$n y ago'`, `'$n mo ago'`,
  `'$n d ago'`, `'$n h ago'`, `'$n m ago'`, and `'Just now'` — genuinely
  user-visible (used across grid item footers, group tiles, the chat
  character switcher, and settings' provider-refresh line). §1 of the
  plan says dates/numbers get "No dedicated phase" beyond the two named
  `DateFormat` call sites Step 2 already wired; `timeAgo()` is a
  hand-rolled formatter, not a `DateFormat` site, so it reads as
  deliberately out of scope rather than a gap in the two-site list.
  Treated as non-action (skip) — flagging since it's a real i18n hole
  (relative-time phrasing/word-order varies a lot by language) in case
  Step 4/5 want to fold it in as a follow-up. The surrounding fixed
  English chrome around each `timeAgo()` call site (e.g. "Last active:",
  "Last refreshed:", "Never") is NOT part of this exclusion and gets
  extracted normally when its owning feature's row comes up.
- **[common] `UtilsApp.sanitizeFileName`'s `fallback = 'Untitled'`**
  (`lib/common/src/utils/utils_app.dart:41`): NOT extracted. Both call
  sites (`lib/character/src/utils/utils_png.dart`) use the default and
  the result becomes an on-disk export filename, not rendered UI text —
  treated like the asset-path/filename exclusion in §3.3, not a UI
  string.

- **[character] `taxonomy_editor_controller.dart`** (~10 validation-error
  return strings: 'Group ID and name are required.', 'Group ID already
  exists.', 'Group not found.', 'Cannot drop a group into itself or its
  descendants.', 'Tag ID and name are required.', 'Tag not found.',
  'Target group not found.', 'Tag ID already exists.'): NOT extracted.
  This is the controller layer behind `DialogTaxonomyEditor`
  (`lib/settings/.../dialog_taxonomy_editor.dart`), which row 5 already
  ruled out of scope as a `kDebugMode`-gated developer surface end users
  never see in release builds. Extending that same call to this
  controller file, since its only consumer is that same dialog.
- **[character] AI-action field names double as LLM prompt content**
  (`lib/character/src/services/character_ai_service.dart`, the literal
  strings `'Name'`, `'Description'`, `'Personality'`, `'Scenario'`,
  `'First Message'`, `'Message Example'`, `'Creator Notes'`, `'System
  Prompt'`, `'Post-History Instructions'`, `'Alternate Greeting #$i'`
  etc. passed as `fieldName` into the batch translate/proofread/compact
  flow): NOT extracted, even though `fieldName` is interpolated into a
  genuinely user-visible progress message (`'Processing $fieldName...'`
  — that wrapper WAS extracted to `t.character.aiActionController
  .processingField`). The `fieldName` value itself is also substituted
  into the LLM prompt via `.replaceAll('%FIELD_NAME%', fieldName)`
  (`character_ai_service.dart` translateText), so translating it would
  change what gets sent to the model, not just what the user reads —
  outside "extract UI strings," and risks coupling UI locale to prompt
  behavior. Left as pass-through English, same treatment as
  `proposal.fieldLabel`/`domain.label` package-data interpolations
  elsewhere in this row.
- **[workspace] Image-style preset chip labels double as generation-prompt
  content** (`lib/workspace/src/pages/widgets/workspace_page/style_presets_dialog.dart`,
  the `_presets` list: `'anime'`, `'photorealistic'`, `'oil painting'`,
  `'watercolor'`, `'pixel art'`, `'comic book'`, `'pencil sketch'`,
  `'digital art'`, `'3D render'`, `'fantasy illustration'`): NOT
  extracted, even though each one is rendered as a `FilterChip` label the
  user reads and taps. Each string is also substring-matched against
  `configMedia.imagePromptPrefix` (`current.toLowerCase().contains(p
  .toLowerCase())`) to derive which chips show as selected, and toggling
  a chip joins the active preset strings directly into that same
  `imagePromptPrefix`, which is fed into image-generation prompts.
  Translating the chip text would change both what's inserted into the
  generation prompt and break the substring match against
  already-persisted English prefixes on existing cards. Same dual-use
  pattern as the character AI-action `fieldName` case above; left as
  pass-through English. The dialog's own chrome ("Image Style" title,
  "No style selected" fallback) WAS extracted since neither value
  touches the prompt string.
- **[nodes] `nodes_debug_dialog.dart` + `nodes_debug_controller.dart`**
  (~30 strings: section titles like "Scene"/"Session"/"Characters"/
  "Pool"/"Event log"/"State changes"/"Director"/"Prompt assembly",
  empty-state text, the whole read-only NODES-engine snapshot body):
  NOT extracted, whole file skipped. Per the class doc comment this is
  a "Read-only snapshot of the NODES engine state" reachable only via
  the `kDebugMode`-gated "NODES Engine" ListTile in
  `workspace_end_drawer.dart` (row 11) — same developer-surface
  exclusion as row 5's Taxonomy Editor. The menu entry itself
  ("NODES Engine" / "Debug snapshot") IS extracted (done in row 11:
  `t.workspace.workspaceEndDrawer.nodesEngineTitle` /
  `.debugSnapshotSubtitle`), same split as the Taxonomy Tags case. The
  rest of `lib/nodes/` (services, repositories, models, the module
  dispatcher) contains no other in-scope strings — every remaining
  literal is either a `loggingService.*` call, a JSON/storage key, or a
  folder/file name. Row 12 has zero extractions; no `nodes.i18n.json`
  content was added and no source files changed.

## Parked observations (bugs noticed but out of scope)
- **[settings, row 5] `SettingsService._loadingStatus` progress strings**
  (`lib/settings/src/services/settings_service.dart:120,134` —
  `'Restoring providers…'` and `'Fetching models ($completed/$total)…'`,
  both assigned to `_loadingStatus` and rendered via `service
  .loadingStatus` in `lib/main.dart`): discovered while extracting the
  analogous `CharacterService._loadingStatus` strings in row 7 — these
  are genuinely user-visible (same startup-loading-screen pattern) but
  were left un-extracted when row 5 (`lib/settings/`, already committed)
  ran. Out of row 7's directory scope (`lib/settings/`, not
  `lib/character/`), so not fixed here to avoid mixing an unrelated
  directory into this row's commit. Flagging for a follow-up pass —
  either folded into Step 4/5 or a small dedicated fix-up commit.
  **Resolved in the §3.7 leftover sweep**: both converted to
  `t.settings.loadingStatus.restoringProviders` /
  `.fetchingModelsProgress(completed, total)`.

## §3.7 leftover sweep (post row-14)
Ran the full self-check: `grep -rn "Text('" lib --include="*.dart"` plus
broader patterns for `label:`/`title:`/`subtitle:`/`hintText:`/
`labelText:`/`helperText:`/`errorText:`/`tooltip:`/`semanticsLabel:`/
`message:`/`content:` (including multi-line forms where the literal
isn't on the same source line as the keyword), `return '...'` in utility
functions, and `showSnackBar('...')`. Every remaining hit was checked
against §3.3 and either matches an existing documented exclusion
(the nodes debug dialog, the taxonomy editor, bare format/technical
identifiers like "GGUF"/"PNG"/"JSON" in native file-picker `XTypeGroup`
labels, `LlmDiagnosticEvent`/`LlmCacheEvent` logger payloads, the
"Cardwave" wordmark, lorebook strategy value-identifiers) or was a
genuine miss, now fixed:
- **`lib/grid/src/pages/widgets/tag_wrap.dart`**: the tag-chip label
  `'${e.key} (${e.value})'` had no `t.` wrapper at all — extracted to
  `t.grid.tagWrap.tagCountLabel(tag, count)`, matching the row 1
  precedent of extracting punctuation/format-only templates (see
  `variantBadge.tooltip`, `filters.indexingProgress` in the same file).
- **`lib/common/src/widgets/custom_log_screen.dart`**: the `'Error:
  ${widget.entry.error}'` prefix label (the log-entry detail panel's own
  chrome, not the logged message itself) was missing its `t.` wrapper —
  extracted to `t.common.logs.errorPrefix(error)`. The raw
  `widget.entry.message`/`.stackTrace`/`.dataContext` content stays
  untouched (that's logger payload, out of scope per §3.3).
- **`lib/common/src/utils/utils_app.dart`**: `UtilsApp.timeAgo()` — used
  across `lib/grid/`, `lib/group/`, `lib/chat/`, and `lib/settings/` for
  "last active"/"imported"/"last refreshed" timestamps — returned six
  raw English literals (`'Xy ago'`, `'Xmo ago'`, `'Xd ago'`, `'Xh ago'`,
  `'Xm ago'`, `'Just now'`) that were never caught by any row because the
  function itself lives in `lib/common/` (row 4) but its only call sites
  are in other directories. Extracted to `t.common.timeAgo.years/months
  /days/hours/minutes(n)` and `.justNow`.
- **`lib/settings/src/services/settings_service.dart`**: the parked
  observation above, now resolved.

Confirmed clean after the fixes: `dart run slang analyze` shows zero
missing `en` keys; `flutter analyze` still shows only the 36 pre-existing
`qcheck` warnings; `flutter test --exclude-tags=integration` is 68/68.
