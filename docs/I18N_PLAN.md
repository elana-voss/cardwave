# Cardwave i18n Plan (multi-model, multi-step)

**Authored by:** Fable (Step 1). **Executed by:** Opus and Sonnet per the step assignments below.
**Companion file:** `docs/I18N_PROGRESS.md` — the live state of this effort. Both files are the
source of truth; conversation context is disposable (see Compaction Protocol).

---

## 0. How to use this document (read first, every model, every session)

1. Read this file top to bottom once, then read `docs/I18N_PROGRESS.md`.
2. Find the first unchecked step in the progress file. **Verify the step's assigned model matches
   the model you are** (your model is named in your system prompt). If it does not match, tell the
   user which model to switch to and STOP. Do not do another model's step "because you can".
3. Execute ONLY your step, following its instructions exactly.
4. After each work unit inside a step: update `docs/I18N_PROGRESS.md` (check the box, add notes),
   include it in the same commit as the work.
5. When your step's DONE-criteria are all met: commit, update the progress file, then print the
   step's **handoff message** verbatim to the user and STOP. Never begin the next step.

### Compaction protocol
- **Between steps:** the user runs `/clear` (preferred over `/compact` — nothing in the
  conversation is needed; these two files carry all state) and switches model. Each step below
  ends with the exact handoff message to print.
- **Within Step 3 (Sonnet):** after each per-feature commit is a safe compaction point. If context
  is getting long, tell the user: "Safe to /compact now" and continue after compaction by
  re-reading the progress file.
- **Session kickoff prompt** (the user pastes this after `/clear`):
  `Read docs/I18N_PLAN.md and docs/I18N_PROGRESS.md, then execute your assigned step. Stop when the step is done.`

### Step → model map
| Step | Work | Model | Compaction before it |
|---|---|---|---|
| 1 | This plan | Fable | — (done) |
| 2 | Infrastructure: slang, locale setting, language modal | **Opus** | `/clear`, switch to Opus |
| 3 | Mechanical string extraction, feature by feature | **Sonnet** | `/clear`, switch to Sonnet |
| 4 | Translation to 8 locales + glossary | **Opus** | `/clear`, switch to Opus |
| 5 | Error-check + Flutter Web verification in Chrome | **Opus** | `/compact` ok (same model as 4) |
| 6 | Optional final acceptance | Fable | `/clear`, switch to Fable |
| 7 | Live-switch repaint + plural fixes | **Opus** | `/clear`, switch to Opus |
| 8 | Language picker on the onboarding page | **Opus** | `/clear`, switch to Opus |

### Global ground rules (all models)
- All work happens on branch `feat/i18n` (created at the start of Step 2). Never commit to `main`.
- One concern per commit. Commit messages: `i18n(<scope>): <what>` e.g. `i18n(grid): extract strings`.
- Never change behavior, fix unrelated bugs, refactor, rename, reformat untouched lines, or
  upgrade dependencies. If you notice a real bug, write it under "Parked observations" in the
  progress file and move on.
- After every commit: `flutter analyze` must be clean and the code must compile.
- Anything ambiguous: add it to "Open questions" in the progress file, choose the NON-action
  (skip it), and continue. Do not invent policy.

---

## 1. Decisions already made (do not relitigate)

| Decision | Choice |
|---|---|
| i18n library | **slang** (+ `slang_flutter`), via the `dart run slang` CLI — NOT wired into `build.yaml`/build_runner (keeps json_serializable builds untouched) |
| Widget-library locales | `flutter_localizations` (GlobalMaterialLocalizations etc.) added alongside |
| Translation file layout | Namespaces = one JSON file per app feature, locale directories: `lib/i18n/<locale>/<namespace>.i18n.json` |
| Base locale | `en` (current English strings). `fallback_strategy: base_locale` so partially-translated builds still run |
| Persistence | `AppSettings.localeTag` (`String?`, `null` = follow system), same pattern as `themeMode` |
| Switch UI | Entry in `SettingsGearMenu` (topnav gear, present on every page) → modal dialog listing ALL languages as a flat tappable list (no dropdown) |
| Language names in the modal | Shown in their own language (locale-invariant), see table below |
| Scope EXCLUDED | Character card content, chat/LLM output, NPC name database, `assets/tags/taxonomy.json` labels, log messages, developer surfaces (Logs screen content may keep technical English values; its chrome/labels are in scope) |
| Dates/numbers | No dedicated phase. Exactly two `DateFormat` call sites get the active locale (Step 2 §2.6) |

### Locales
| App locale tag | slang file dir | Modal display name | Notes |
|---|---|---|---|
| `en` | `lib/i18n/en/` | English | base |
| `ru` | `lib/i18n/ru/` | Русский | plurals: one/few/many/other |
| `pt-BR` | `lib/i18n/pt-BR/` | Português (Brasil) | Flutter's Material `pt` IS pt-BR |
| `es-419` | `lib/i18n/es-419/` | Español (Latinoamérica) | CONTINGENCY: if slang cannot parse the `419` region, use plain `es` everywhere instead (dir `lib/i18n/es/`), keep Latin-American phrasing. Record the outcome in the progress file. |
| `ja` | `lib/i18n/ja/` | 日本語 | no plural forms (other only) |
| `zh-Hans` | `lib/i18n/zh-Hans/` | 简体中文 | maps zh-CN |
| `zh-Hant` | `lib/i18n/zh-Hant/` | 繁體中文 | covers TW + HK for v1 |
| `ko` | `lib/i18n/ko/` | 한국어 | no plural forms |
| `hi` | `lib/i18n/hi/` | हिन्दी | plurals: one/other |

### Namespaces (fixed list — do not add others without an Open-question entry)
`app` (bootstrap/error/shared chrome), `common`, `grid`, `character`, `chat`, `editor`, `group`,
`llmApp`, `memory`, `nodes`, `onboarding`, `routing`, `search`, `settings`, `workspace`.

---

## 2. STEP 2 — Infrastructure (**Opus**)

Goal: the app compiles with slang wired end-to-end, a working language modal reachable from the
gear menu on every page, live switching, persistence across restart. English-only content at this
point (all 9 locale dirs exist; the 8 non-en ones contain the namespace files with `{}` empty
objects — slang falls back to base locale).

### 2.1 Branch + dependencies
- `git checkout -b feat/i18n`
- Root `pubspec.yaml`: add `slang`, `slang_flutter` (latest compatible with Dart ^3.10), and
  `flutter_localizations: {sdk: flutter}` to `dependencies`. Do NOT touch `build.yaml`. Do NOT
  add slang to any `packages/*` pubspec.
- Create `slang.yaml` at repo root:

```yaml
base_locale: en
fallback_strategy: base_locale
input_directory: lib/i18n
input_file_pattern: .i18n.json
output_directory: lib/i18n/gen
output_file_name: translations.g.dart
namespaces: true
locale_handling: true
flutter_integration: true
string_interpolation: dart
timestamp: false
```

- Create `lib/i18n/en/<namespace>.i18n.json` for every namespace in §1 (empty `{}` except the ones
  Step 2 itself needs), and the same set for the 8 other locales as `{}`.
- Generate: `dart run slang`. Commit checkpoint.

### 2.2 Settings model
`lib/settings/src/models/app_settings.dart`: add field, mirroring how `themeMode` is declared:

```dart
/// BCP-47 tag of the UI language ('ru', 'pt-BR', ...). Null follows the
/// device locale.
String? localeTag;
```

Add to constructor (default `null`), regenerate json_serializable
(`dart run build_runner build --delete-conflicting-outputs`).

### 2.3 Locale controller
Follow the existing `ThemeNotifier` pattern (`lib/common/src/utils/theme_notifier.dart` — read it
first and mirror its structure). Create `lib/settings/src/services/locale_controller.dart` (or the
directory convention you find fits — check `lib/settings/src/services/`):

- Exposes the current `AppLocale?` (null = system) and `void setLocale(String? tag)` which:
  1. calls `LocaleSettings.setLocaleRaw(tag)` or `LocaleSettings.useDeviceLocale()` when null,
  2. writes `settings.localeTag`, `unawaited(settingsService.saveSettings())`,
  3. `notifyListeners()`.
- At app bootstrap (where `ThemeNotifier` is initialized from loaded settings in
  `app_bootstrapper.dart`): apply the persisted tag once, same trigger point.

### 2.4 MaterialApp wiring — all three in `lib/main.dart`
The main app (`main.dart:746` area, `_MyAppState.build`):
- Wrap `MyApp`'s child position in `AppBootstrapper.build` (main.dart:714 `child: const MyApp()`)
  as `child: TranslationProvider(child: const MyApp())`.
- On the `MaterialApp`:

```dart
locale: TranslationProvider.of(context).flutterLocale,
supportedLocales: AppLocaleUtils.supportedLocales,
localizationsDelegates: GlobalMaterialLocalizations.delegates,
```

The error app (main.dart:639) and loading app (main.dart:659) run BEFORE settings load: give them
`supportedLocales` + `localizationsDelegates` only (no `locale:`), content stays English.

### 2.5 Gear-menu entry + modal
`lib/settings/src/pages/widgets/settings_gear_menu.dart`:
- Add `language` to `_GearActionEnum`.
- New `PopupMenuItem` placed directly ABOVE the existing 'App Settings' item (inside the same
  divider group): `key: Key('settings-language')`, `leading: Icon(Icons.language)`,
  `title: Text('Language')` (extract to `t.settings.gearLanguage` — this step already writes real
  keys for the strings it touches).
- Handler: `NavigationService().showLanguageDialog()`.

`NavigationService` (`lib/common/src/utils/navigation_service.dart`): add `showLanguageDialog()`
modeled EXACTLY on `showPersonasDialog()` (`_showAppDialog` + `AppDialog`, see line ~203).

New widget `lib/settings/src/pages/widgets/dialog_language_picker.dart`:
- A flat, scrollable `ListView` of 10 `ListTile`s — first "System default" (localized string
  `t.settings.languageSystemDefault`), then the 9 languages from the table in §1 in that order,
  each showing its native display name (hardcoded constants — these are intentionally NOT
  translation keys) with the English name as a subtitle for non-Latin scripts
  (e.g. 日本語 / "Japanese"). No dropdown, no search, all rows visible by scrolling.
- Current selection marked with a trailing `Icon(Icons.check)`.
- Tap → `LocaleController.setLocale(tag)` → pop the dialog. UI must re-render in the new
  language immediately (verify: gear tooltip, drawer labels).
- Keys: `Key('language-tile-<tag>')`, `Key('language-tile-system')`.

### 2.6 The two DateFormat call sites
- `lib/chat/src/pages/widgets/chat_list_item.dart:25` — pass the active locale:
  `DateFormat.yMMMd(LocaleSettings.currentLocale.languageTag).add_jm()`.
- `lib/chat/src/pages/widgets/chat_message_bubble/message_actions_row.dart:32` — this is a
  `static final` (caches the first locale forever). Make it a non-static getter or build it
  in-place with the current locale tag.

### 2.7 DONE criteria (all must pass)
- [ ] `flutter analyze` clean; `dart run slang analyze` reports no issues; `flutter test` passes.
- [ ] Run on Windows desktop (`flutter run -d windows`): gear → Language → modal lists all 10
      entries; picking Русский immediately changes visible chrome that already has keys; restart
      the app → still Русский; pick System default → follows OS.
- [ ] Commits pushed to `feat/i18n`; progress file updated (including the es-419 contingency
      outcome).

### 2.8 Handoff — print verbatim, then STOP
> Step 2 complete. Please run `/clear`, switch to **Sonnet** (`/model sonnet`), and paste the
> session kickoff prompt from docs/I18N_PLAN.md §0.

---

## 3. STEP 3 — String extraction (**Sonnet**)

You are doing MECHANICAL work. Follow the rules below to the letter. Do not improve code, do not
fix bugs, do not reword any English string (the extracted value must be byte-identical to the
original, including punctuation, `\n`, and trailing spaces). Do not touch `packages/*`. When any
situation is not covered by a rule, DO NOT decide: skip it, write it under "Open questions" in
`docs/I18N_PROGRESS.md`, and continue.

### 3.1 Work order — one feature per commit, in this exact order
Progress boxes for each are in the progress file. After EACH feature: regenerate, verify (§3.6),
commit `i18n(<feature>): extract strings`, update progress file. Each commit is a safe
**compaction point** — tell the user "Safe to /compact now" when context is long.

| # | Directory | Namespace | ~strings (estimate) |
|---|---|---|---|
| 1 | `lib/grid/` | `grid` | 41 |
| 2 | `lib/routing/` | `routing` | 3 |
| 3 | `lib/onboarding/` | `onboarding` | 19 |
| 4 | `lib/common/` | `common` | 49 |
| 5 | `lib/settings/` | `settings` | 112 |
| 6 | `lib/llm_app/` | `llmApp` | 26 |
| 7 | `lib/character/` | `character` | 15 |
| 8 | `lib/chat/` | `chat` | 80 |
| 9 | `lib/editor/` | `editor` | 161 (split into 2 commits if needed) |
| 10 | `lib/group/` | `group` | 40 |
| 11 | `lib/workspace/` | `workspace` | 25 |
| 12 | `lib/nodes/` | `nodes` | 12 |
| 13 | `lib/memory/`, `lib/search/` | `memory`, `search` | ~0 (verify, likely nothing) |
| 14 | `lib/main.dart`, `lib/app_bootstrapper.dart`, `lib/my_app.dart`, `lib/app_router.dart` | `app` | few |

### 3.2 What to extract (ALL of these, nothing else)
A string literal is IN SCOPE only if a user sees it rendered in the UI:
- `Text('...')`, `label:`, `title:`, `subtitle:`, `hintText:`, `labelText:`, `helperText:`,
  `errorText:`, `tooltip:`, `semanticsLabel:`, `SnackBar(content: Text('...'))`,
  dialog titles/bodies/button labels, `TextSpan(text: '...')`, empty-state messages,
  user-visible error strings shown via SnackBar/dialog.
- Enum display labels (e.g. a `String get label` on an enum): replace the returned literals with
  `t.<ns>.<enum>.<value>` keys, one key per enum value.

### 3.3 What to NEVER extract
- `Key('...')` / `ValueKey` / test keys — never.
- Logger calls (`_loggingService.*`, `Logger`, `debugPrint`, `buffer.write` diagnostics),
  exception messages that are only thrown/logged, `assert` messages.
- Asset paths, URLs, route names, JSON field names, IDs, MIME types, file extensions,
  regex patterns, prompt text sent to LLMs, anything inside `packages/*`.
- Strings already using a `t.` key (Step 2 created some in `settings`).
- The native language names in `dialog_language_picker.dart`.
- Single characters and pure punctuation/whitespace (`' '`, `'—'`, `'...'` used as spacers).

### 3.4 Key naming
- camelCase, grouped by widget/dialog with nesting max 2 levels:
  `t.grid.appBar.createNew`, `t.chat.deleteDialog.title`.
- Name by MEANING not by value: `'OK'` → `common.ok` (put cross-feature strings like
  OK/Cancel/Save/Delete/Close/Retry in `common.actions.*` and reuse — check `common` first
  before minting a per-feature duplicate of these six words; for anything else, duplicate keys
  per feature are fine and preferred over guessing shared semantics).
- The JSON value must be the exact original English string.

### 3.5 Transformation examples — copy these patterns exactly

**A. Plain literal (note: `const` must be removed from the affected constructor only):**
```dart
// BEFORE  (lib/grid/src/pages/widgets/app_bar_grid.dart)
label: const Text('Groups'),
// AFTER
label: Text(t.grid.appBar.groups),
```
```json
// lib/i18n/en/grid.i18n.json
{ "appBar": { "groups": "Groups" } }
```
Import: `import 'package:cardwave/i18n/gen/translations.g.dart';` (adjust to the actual generated
path/export from Step 2 — look at how Step 2's own extractions import it and copy that).

**B. Interpolation → parameter:**
```dart
// BEFORE
Text('Failed to initialize app:\n\n$_error')
// AFTER
Text(t.app.initFailed(error: _error))
```
```json
{ "initFailed": "Failed to initialize app:\n\n$error" }
```

**C. Count → plural (only when the number changes the noun):**
```dart
// BEFORE
Text('$count cards selected')
// AFTER
Text(t.grid.selection.count(n: count))
```
```json
{ "selection": { "count(plural)": { "one": "$n card selected", "other": "$n cards selected" } } }
```
English plurals need only `one` + `other`. Other locales are Step 4's problem, not yours.

**D. Adjacent const-ness:** if removing `const` from a `Text` breaks a `const` list or parent,
remove `const` from the smallest enclosing expression only. Never restructure the widget tree.

**E. Widget tests:** the base locale is `en`, so existing `find.text('Groups')` assertions keep
passing. If a test fails after your change, the ONLY permitted fixes are (a) updating the expected
literal if you changed which widget renders it, or (b) wrapping the pumped widget in
`TranslationProvider(child: ...)`. Anything else → Open questions + skip.

### 3.6 Per-feature verification loop (run after EVERY feature, before its commit)
1. `dart run slang` (regenerate — generated file compiles)
2. `flutter analyze` → must be clean
3. `flutter test` → must pass (integration_test excluded)
4. `git add -A && git commit -m "i18n(<feature>): extract strings"` (progress file included)

### 3.7 DONE criteria
- [ ] All 14 rows in §3.1 checked off in the progress file.
- [ ] `dart run slang analyze` shows no missing translations for `en` and (expected) all keys
      missing for the other 8 locales.
- [ ] A final self-check sweep: `grep -rn "Text('" lib --include="*.dart"` — every remaining hit
      is justifiable under §3.3; list any doubtful leftovers in Open questions.

### 3.8 Handoff — print verbatim, then STOP
> Step 3 complete. Please run `/clear`, switch to **Opus** (`/model opus`), and paste the
> session kickoff prompt from docs/I18N_PLAN.md §0.

---

## 4. STEP 4 — Translation + glossary (**Opus**)

Goal: all 8 non-English locales fully translated, a glossary committed, zero missing keys.
No human review will happen — your self-review IS the review. Work one LANGUAGE at a time,
commit per language (`i18n(l10n): translate ru`), each commit a safe compaction point.

### 4.1 First: resolve Step 3's Open questions
Read the Open questions section of the progress file. For each: decide (you have judgment
authority Sonnet did not), apply the fix if extraction is warranted, document the decision inline.

### 4.2 Glossary — create BEFORE translating
`docs/I18N_GLOSSARY.md`: table of domain terms × 8 languages. Every recurring term gets ONE
canonical translation used everywhere. Seed list (extend as you go): character card, character,
persona, chat, group chat, workspace, prompt, provider, preset, model, memory, tag, import,
export, library. Terms that stay untranslated everywhere: Cardwave, LLM, API key, token, GGUF,
provider product names. Example row:

| en | ru | pt-BR | es-419 | ja | zh-Hans | zh-Hant | ko | hi |
|---|---|---|---|---|---|---|---|---|
| character card | карточка персонажа | cartão de personagem | tarjeta de personaje | キャラクターカード | 角色卡 | 角色卡 | 캐릭터 카드 | कैरेक्टर कार्ड |

### 4.3 Register & style per language (this app is a consumer roleplay/creative tool — friendly, not corporate)
- **ru**: address the user with «вы» (lowercase), buttons in infinitive («Создать», «Импортировать»). Plural keys need `one`/`few`/`many` (+`other`).
- **pt-BR**: «você» register, warm and direct; avoid European Portuguese vocabulary (e.g. use "salvar" not "guardar", "deletar/excluir" not "apagar" where natural).
- **es-419**: neutral Latin-American Spanish; «tú» for direct address; avoid vosotros and Peninsular idioms ("computadora" not "ordenador").
- **ja**: です/ます polite form for sentences; buttons as noun/verb-stem («作成», «インポート»); no spaces around interpolations.
- **zh-Hans vs zh-Hant**: not a script transliteration — terminology differs (设置/設定 for settings, 导入/匯入 for import, 视频/影片 for video). Translate zh-Hant independently with Taiwan conventions.
- **ko**: 해요체 for messages, noun-form buttons («만들기», «가져오기»); keep particles correct around interpolations (prefer particle-free phrasings where a name is substituted).
- **hi**: formal «आप»; established English loanwords in Devanagari are fine and often preferred (सेटिंग्स, इम्पोर्ट) — prioritize naturalness over purism.

### 4.4 Mechanical invariants (check per file as you write)
- Key structure mirrors `en` exactly (same nesting, same keys, same `(plural)` modifiers with the
  locale's required CLDR categories: ru one/few/many/other; hi one/other; pt-BR/es one/other;
  ja/zh/ko other only).
- Interpolation placeholders `$name`/`${name}` preserved verbatim, never translated, never dropped.
- `\n` counts preserved. No trailing whitespace added.
- If ja/zh/ko lack a plural resolver in slang, register resolvers via
  `LocaleSettings.setPluralResolver` at bootstrap (single-category languages: always `other`).

### 4.5 Self-review pass (after all 8 languages)
For each language, re-read every file end-to-end in one sitting checking ONLY: glossary
consistency, placeholder integrity, register consistency, obviously machine-stiff phrasings.
Fix in place; commit `i18n(l10n): review pass`.

### 4.6 DONE criteria
- [ ] `dart run slang analyze` → zero missing, zero unused keys across all 9 locales.
- [ ] `dart run slang` + `flutter analyze` + `flutter test` clean.
- [ ] Glossary committed; progress file updated.

### 4.7 Handoff — print verbatim, then STOP
> Step 4 complete. Staying on **Opus** for Step 5 — run `/compact` (or `/clear` and re-paste the
> kickoff prompt) and continue with Step 5.

---

## 5. STEP 5 — Error-check + Flutter Web verification (**Opus**)

### 5.1 Code review of the whole branch
`git diff main...feat/i18n` reviewed with skepticism, hunting specifically for:
- Extraction mistakes: swapped keys (string A under key B), lost/renamed interpolation params,
  dropped `\n`, extracted strings that are actually IDs/routes/log lines, missed plurals
  (`'$n items'` extracted as plain param instead of plural).
- Behavior drift: any diff hunk that changes logic, not just strings/const-ness.
- Leftovers: sample-grep for hardcoded literals in user-facing params
  (`label:`, `tooltip:`, `hintText:`, `SnackBar`) and judge each hit against §3.3.
Fix what you find; commit `i18n(review): fixes`.

### 5.2 Full verification
`flutter analyze`, `flutter test`, `dart run slang analyze` — all clean.

### 5.3 Web smoke test in Chrome (all 9 languages)
1. `flutter run -d chrome` (or `flutter build web` + serve; runner gives hot restart which is faster).
2. Drive the app via the chrome-devtools MCP tools. For EACH of the 9 languages:
   - Switch via gear → Language → tap the language tile.
   - Screenshot: library grid view, the gear menu open, the end drawer open, one dialog
     (e.g. the language modal itself).
   - Check: (a) **tofu/□□□ glyphs** — highest risk for ja/zh/ko/hi since only NotoSans
     (Latin/Cyrillic) is bundled; (b) truncated/overflowing buttons and appbar labels (ru and
     pt-BR run ~25% longer than en); (c) Flutter's yellow/black overflow stripes; (d) console
     errors via `list_console_messages`.
3. Persistence: switch to `ru`, reload the page, verify it comes back in `ru`.
4. Record a per-language pass/fail table with screenshot paths in the progress file.

### 5.4 Font contingency (only if tofu appears)
Do NOT bundle multi-MB CJK fonts on your own authority. Report which locales/platforms show tofu
and propose the minimal fix (e.g. `fontFamilyFallback` with system families, or bundling a subset
font) — this is a user decision (binary size). Park it in the progress file under Open questions.

### 5.5 DONE criteria
- [ ] Review fixes committed; all checks in §5.2 clean; §5.3 table complete in progress file.

### 5.6 Handoff — print verbatim, then STOP
> Step 5 complete. i18n branch is ready. Optionally run `/clear`, switch to **Fable**
> (`/model fable`) for the Step 6 acceptance spot-check — or merge `feat/i18n` if you're satisfied.

---

## 6. STEP 6 — Optional acceptance (**Fable**)
Spot-check: progress file + open questions review, 10 random diff hunks from Step 3 commits,
3 random translated files against the glossary, the §5.3 results table. Verdict: merge or a
punch list. Also decide/propose the follow-up qcheck lint rule (flag new hardcoded literals in
widget code) as a separate future task.

---

## 7. STEP 7 — Live-switch repaint + plural fixes (**Opus**)

Added after Step 6 acceptance: the user requires live language switching before merge (Step 2
§2.5's "re-render immediately" is currently unmet — see the Step-5 HEADLINE open question), plus
correct plural forms for the ~6 count strings whose original English was never pluralized.
All global ground rules (§0) apply. Two concerns → two commits.

### 7.1 Context-based translations pass — commit `i18n(l10n): live locale switching`
Root cause recap: the global `t` accessor never subscribes a widget to `TranslationProvider`,
so `LocaleSettings.setLocaleRaw` repaints nothing that isn't rebuilt for other reasons.
The generated API (confirmed in `lib/i18n/gen/translations.g.dart`) provides
`Translations.of(context)` and a `context.t` extension — reading either registers an
InheritedWidget dependency, which triggers rebuild on locale change **even for `const` widget
instances** (dependencies live on the Element, not the widget).

The transformation, applied file by file:
1. In every widget `build(BuildContext context)` method whose method body (or helpers it calls
   in the same class) reads `t.` — add as the FIRST line:
   `final t = Translations.of(context);`
   The local `t` shadows the global import, so **no other line in the method changes**. If the
   method already has a `final t = ...` collision, it won't (verify), otherwise flag it.
2. Class-level helper methods on widgets that take no `BuildContext` and read `t.` need no
   change — they're only invoked from a build that now registers the dependency.
3. Do NOT touch: controllers, services, enum `label` getters, dialog/snackbar content built at
   interaction time (`NavigationService`, `showDialog` builders — those build fresh when opened),
   and non-widget code. They keep the global `t`.
4. Builder callbacks (`itemBuilder:`, `PopupMenuButton`, etc.) inside menus/dialogs rebuild on
   open — no change needed. A builder that stays mounted on the page (e.g. `ListView.builder`
   item builders) is covered by its enclosing widget's build registering the dependency.

Finding the surface: `grep -rln "\bt\." lib --include="*.dart"` minus the excluded categories in
rule 3; expect the bulk of extracted widget files. Mechanical, but verify each file compiles as
you go in batches; `flutter analyze` clean before the commit.

### 7.2 Plural upgrade — commit `i18n(l10n): pluralize count strings`
Convert these 6 keys from plain-param to `(plural)` keys in ALL 9 locale files (categories per
§4.4: ru one/few/many/other; hi + pt-BR + es-419 + en one/other; ja/zh-Hans/zh-Hant/ko other
only), keeping the existing placeholder name (`$count`) and following the glossary + register
rules from §4.2/§4.3:
- `chat.chatListItem.messageCount` ("$count messages")
- `character.importController.importedCount` ("Imported $count characters")
- `common.importConflictsDialog.message`
- `common.diffPanel.tokenSuffix`
- `common.textFieldCard.labelWithTokenCount`
- `grid.variantBadge.tooltip` ("$count Variants")
The English `one` forms fix the pre-existing "1 messages"-class bugs; `other` forms stay
byte-identical to today's values. All other `$count`/`$n` strings are numeric counters
("3 / 10", "+2", "$count t") — do NOT touch them. Call sites keep working (slang generates the
same method signature for plural keys); regenerate with `dart run slang` and confirm no call-site
edits are needed (if one is, it's a named-param rename only).

### 7.3 Verification (DONE criteria)
- [ ] `flutter analyze` (only the 36 pre-existing qcheck warnings), `flutter test` (68/68),
      `dart run slang analyze` (0 missing / 0 unused).
- [ ] Web run (`flutter run -d web-server`, chrome-devtools MCP, enable a11y placeholder per
      load): switch language via gear → Language and confirm — WITHOUT any reload — that the
      grid app bar (`Create New`/`Import`/`Groups`), the search hint, and the gear-menu labels
      repaint in the new language. Per the user's earlier guidance, verifying the live switch in
      **two** locales (e.g. en→ru→ja) is sufficient; no 9-locale re-sweep.
- [ ] Plural spot-check in ONE inflecting locale (ru): a count=1 surface renders the `one` form.
- [ ] Progress file updated (Step 7 checklist + resolve the Step-5 HEADLINE open question as
      fixed); both commits on `feat/i18n`.

### 7.4 Handoff — print verbatim, then STOP
> Step 7 complete. Live language switching works without reload and the count strings are
> pluralized. `feat/i18n` is ready to merge.

---

## 8. STEP 8 — Language picker on the onboarding page (**Opus**)

Added after Step 7 (2026-07-12). Rationale: on first launch the app follows the device locale
(`LocaleController.applyPersisted` → `useDeviceLocale()`, English fallback), but a user whose
device language is not the one they read has no way to change it during onboarding — the gear
menu doesn't exist there. Fix: a globe icon in the onboarding AppBar that opens the EXISTING
language dialog. All global ground rules (§0) apply. **One concern → ONE commit:**
`i18n(onboarding): language picker in onboarding`.

Everything below was verified against the code on 2026-07-12; re-verify line numbers before
editing but do not re-derive the approach.

### 8.1 REQUIRED FIRST — persistence guard in `LocaleController.setLocale`
**The trap (do not skip this or the feature crashes):**
`LocaleController.setLocale` (`lib/settings/src/services/locale_controller.dart:27`) calls
`SettingsService().saveSettings()`. `saveSettings`
(`lib/settings/src/services/settings_service.dart:83`) writes the recovery mirror using
`_settings.characterPath!` (line 87) — a null assertion. During onboarding `characterPath` is
still null (it's first assigned in `OnboardingController.finishOnboarding`,
`lib/onboarding/src/controllers/onboarding_controller.dart:211-216`), so picking a language
from the onboarding screen would throw.

**The fix — guard the save, keep everything else:** in `setLocale`, still (1) switch the live
slang locale, (2) write `settings.localeTag = tag` in memory, (3) `notifyListeners()` — but only
call `unawaited(settingsService.saveSettings())` when
`settingsService.settings.onboardingComplete` is true (`onboardingComplete` is the project's
established first-launch predicate). During onboarding the in-memory `localeTag` is then
persisted by `finishOnboarding`'s own `saveSettings()` (onboarding_controller.dart:260) — no
extra persistence code needed. Update `setLocale`'s doc comment to say why the save is guarded.
Accepted trade-off (do not "fix"): a user who picks a language and then quits before finishing
onboarding loses the choice.

Do NOT touch `saveSettings` / the recovery mirror / the `characterPath!` assertion — out of
scope for this step.

### 8.2 The button
`lib/onboarding/src/pages/onboarding_page.dart` — in `_OnboardingPageState.build` (the
`Scaffold`'s `AppBar` at ~line 86, which is shared by BOTH the stepped desktop layout and the
single-page mobile/web layout), add:

```dart
appBar: AppBar(
  title: Text(t.onboarding.appBarTitle),
  centerTitle: true,
  actions: [
    IconButton(
      key: const Key('onboarding-language'),
      icon: const Icon(Icons.language),
      tooltip: t.onboarding.languageTooltip,
      onPressed: () => unawaited(NavigationService().showLanguageDialog()),
    ),
  ],
),
```

- `NavigationService().showLanguageDialog()` already exists
  (`lib/common/src/utils/navigation_service.dart:216`) and opens `DialogLanguagePicker` in an
  `AppDialog`. Calling it straight from a widget handler is the established precedent for this
  exact dialog — `settings_gear_menu.dart:137` does the same. Do NOT build a new picker, a
  dropdown, or a controller method.
- `dart:async` (`unawaited`) and `NavigationService` are already imported in the file.
- Reuse the existing `Key` style; the widget-key string is not a translation key (§3.3).

**Why no other code changes are needed:** `_OnboardingPageState.build` already registers the
locale dependency via `final t = Translations.of(context);` (line 84), so when the dialog
switches the locale, the entire onboarding page — including the Step titles built by State
helper methods that read the global `t` — repaints live (Step 7 §7.1 rule 2 mechanics). The
dialog itself pops on selection and the tapped choice flows through `LocaleController` exactly
as it does from the gear menu.

### 8.3 The tooltip key
New key in the `onboarding` namespace, all 9 locales
(`lib/i18n/<locale>/onboarding.i18n.json`): top-level `"languageTooltip"`. The value for every
locale is copied VERBATIM from that same locale's existing
`settings.i18n.json → "gearLanguage"` (en: `"Language"`) — same word, already translated and
glossary-checked in Step 4. Do not re-translate, do not reuse the settings key cross-namespace
(§3.4 forbids it). Then `dart run slang` to regenerate.

### 8.4 Verification (DONE criteria)
- [ ] `flutter analyze` — only the 36 pre-existing qcheck warnings; `flutter test` — 68/68
      (no new tests required: pumping `OnboardingPage` needs three provided services and is not
      worth the harness; do not add one); `dart run slang analyze` — 0 missing / 0 unused.
- [ ] Manual web run with FRESH storage so onboarding actually shows
      (`flutter run -d web-server`, open in a fresh incognito profile / clear site data;
      chrome-devtools MCP, enable the a11y placeholder per load). On the onboarding screen:
      1. Globe icon visible in the AppBar; tap → language dialog opens.
      2. Pick **Русский** → onboarding repaints in Russian immediately, NO crash (this
         exercises the §8.1 guard — a crash here means the guard is missing/wrong).
      3. Re-open the dialog, pick **System default** → no crash, back to device locale.
      4. Pick Русский again, complete onboarding (Start Fresh path) → app lands on the grid in
         Russian; reload the page → still Russian (proves `finishOnboarding` persisted the tag).
- [ ] Console clean during the switches (`list_console_messages`).
- [ ] Progress file updated (Step 8 checklist + Steps list); single commit on `feat/i18n`.

### 8.5 Handoff — print verbatim, then STOP
> Step 8 complete. Onboarding has a language picker (globe icon → existing dialog); the choice
> applies live and persists via finishOnboarding. `feat/i18n` is ready to merge.
