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
- [ ] 4 `lib/common/` → `common`
- [ ] 5 `lib/settings/` → `settings`
- [ ] 6 `lib/llm_app/` → `llmApp`
- [ ] 7 `lib/character/` → `character`
- [ ] 8 `lib/chat/` → `chat`
- [ ] 9 `lib/editor/` → `editor`
- [ ] 10 `lib/group/` → `group`
- [ ] 11 `lib/workspace/` → `workspace`
- [ ] 12 `lib/nodes/` → `nodes`
- [ ] 13 `lib/memory/` + `lib/search/`
- [ ] 14 root files → `app`
- [ ] 3.7 final leftover sweep done

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
  dialog_local_gguf_provider_config.dart).

## Parked observations (bugs noticed but out of scope)
_(none yet)_
