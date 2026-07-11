# i18n Progress

Live state for `docs/I18N_PLAN.md`. Every executing model updates this file in the same commit
as the work it describes. Conversation context is disposable; this file is not.

## Steps
- [x] Step 1 — Plan (Fable) — done 2026-07-11
- [ ] Step 2 — Infrastructure (**Opus**)
- [ ] Step 3 — Extraction (**Sonnet**)
- [ ] Step 4 — Translation + glossary (**Opus**)
- [ ] Step 5 — Error-check + web verification (**Opus**)
- [ ] Step 6 — Optional acceptance (Fable)

## Step 2 checklist (Opus)
- [x] 2.1 branch `feat/i18n` + deps + slang.yaml + locale skeleton files + first generate
- [ ] 2.2 `AppSettings.localeTag` + json regen
- [ ] 2.3 LocaleController + bootstrap apply
- [ ] 2.4 TranslationProvider + all three MaterialApps wired
- [ ] 2.5 gear-menu entry + `showLanguageDialog` + `DialogLanguagePicker`
- [ ] 2.6 two DateFormat call sites locale-aware
- [ ] 2.7 DONE criteria verified on Windows desktop
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

## Step 3 checklist (Sonnet) — one commit per row
- [ ] 1 `lib/grid/` → `grid`
- [ ] 2 `lib/routing/` → `routing`
- [ ] 3 `lib/onboarding/` → `onboarding`
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
_(none yet)_

## Parked observations (bugs noticed but out of scope)
_(none yet)_
