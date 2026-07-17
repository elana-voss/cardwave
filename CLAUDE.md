# CLAUDE.md

Project-specific guidance for Claude Code working in this Flutter/Dart repo (`elana-voss/cardwave`, the public app).

## ⚠️ NEVER RUN `dart analyze` / `flutter analyze`

**They hang indefinitely here** — the root `analysis_options.yaml` loads the qcheck analyzer plugin and the CLI analysis server stalls booting it. This is not a "try it and see"; it wedges and must be killed by PID. Verify with:

- `flutter test` (or `flutter test <file>`) — catches compile errors and runs the suite.
- `& "C:\Users\theco\ai\software\qcheck\build\qcheck.exe" analyze <paths>` from the repo root — the project's CLI lint.

**qcheck baseline is zero.** `qcheck.exe analyze lib/ packages/` must report no findings and exit 0. Warnings are never an acceptable baseline (except TODOs). A change that introduces a finding either fixes it or suppresses it with `// ignore: qcheck/<rule>` plus a one-line reason, placed on the exact line qcheck anchors to (the parameter or expression it names — not the declaration or doc comment above it). The root `pubspec.yaml` is outside that command's scope and still carries findings.

IDE diagnostics from the analysis server can be **commits stale** (reporting symbols that a prior commit deleted). Read the file before acting on a diagnostic that looks surprising.

## ⚠️ TOKEN DISCIPLINE — apply by default

The user pays per token. Apply without being asked.

- **Parallelize independent tool calls.** Multiple WebFetches, Greps, or Reads of unrelated files go in ONE assistant message with N tool-use blocks. Sequential calls are 2–3× the cost.
- **Probe the cheapest source first.** `git log --oneline -10` before reading a long handoff doc. Registry imports before barrel files. Focused Grep before full Read. Long docs are often stale — a 10-line probe answers the same question for 100 tokens vs 5K.
- **Targeted reads, not full-file reads.** For surgical edits to known-structure files (registries, barrels, manifests), use Grep to find the insertion point, then Read with `offset`+`limit`, then targeted Edit. Reading 200 lines to make a 4-line edit wastes ~2K tokens.
- **Don't re-read after Edit/Write.** They error if the change failed. Re-reading "to verify" doubles the cost of every edit.
- **Don't re-verify within a session.** If I checked something exists once (an API, file, constant), don't re-check later. Memorize for the duration.
- **Prefer Grep/Glob over Bash grep/find/ls.** Permission-cached, narrower output. Reserve Bash for shell-only operations.
- **Don't run `/errors` or `/simplify` unless the user asks.** Expensive (50–80K tokens).
- **Never build, compile, run, launch, relaunch, or screenshot the app unless the user explicitly and unambiguously asks for that exact action.** A Windows build costs minutes + real money; relaunching kills the window the user already has open; screenshots cost tokens. Default after a code change: make the edit, run `flutter test` / qcheck if useful, then STOP — the user builds, runs, and looks at the app themselves. Vague cues ("test it", "fix X", "in a branch") do NOT authorize a build/run/launch — if it's not a literal "build it" / "run it" / "screenshot it", ask first.
- **Don't auto-commit.** Commit only on explicit "commit" / "ship". Cycle: implement → `flutter test` + qcheck → continue.
- **Skip TodoWrite churn for short workflows.** Track only when visibility helps the user.

The biggest single waste is sequential research where one parallel batch would do.

## ⚠️ GREENFIELD — read first, every session

**The app is under active development. There are no production users. Backwards compatibility is NOT a concern. This rule is violated repeatedly — stop violating it.**

- No backward-compat shims. No migration code. No fallback paths for removed behavior.
- When renaming a Dart field, **rename the `@JsonKey(name: ...)` to match.** Do not preserve old JSON keys unless user explicitly asks.
- Cached files on disk are disposable. The user can re-import.
- Do not "preserve old behavior just in case" — delete cleanly.
- Do not propose `?? legacyValue`, `if (oldField != null)` branches, dual-read, dual-write. If you catch yourself adding one, stop and rewrite.
- Settings files are self-healing: an unknown or removed enum value makes `$enumDecode` throw, `SettingsRepository.loadSettings` catches, and the app falls back to fresh defaults + the provider recovery file (API keys survive). That is the migration path. Don't write a shim for it.

Before every code change, ask: am I keeping a fallback / shim / legacy path I should be deleting? Same scan applies before writing a plan file.

## Architectural layering

Strict unidirectional flow. A layer may only depend on the layer below. Utils is cross-cutting.

1. **UI** — declarative layout/styling only. No business logic.
2. **Controller** — UI state, orchestrates Services.
3. **Service** — business logic, coordinates Repositories.
4. **Repository** — data sources, maps to domain models.
5. **IO** — raw external comms (HTTP, DB, fs).
6. **Utils** — stateless helpers, accessible from any layer.

UI never calls Repository or IO directly. Service never reaches into UI state.

### Dialogs

- **No widget opens a dialog directly.** The controller opens dialogs via `NavigationService` (or its `showXxxDialog` helpers); the widget dispatches to the controller.
- **Pick the controller flavour by complexity:**
  - **Simple dialogs (no per-instance state) → static-method controller.** One-shot flows: confirm-and-delete, pick-and-apply, import-and-report. Plain class with `const X._()` private constructor; methods are `static`. Pass services as arguments. Examples: `CharacterImportController`, `MediaSettingsController`, `FilterController` (and similar one-shot flows).
  - **Complex stateful dialogs → `ChangeNotifier` controller via `Provider`.** Multi-step forms, text-edit controllers per field, in-flight operations, methods sharing mutable state across rebuilds. Created in host widget's `initState`, disposed in `dispose`, exposed via `ChangeNotifierProvider.value`; reactive parts use `Consumer<X>`. Examples: `ChatController`, `GroupChatController`, `DialogPresetConfigController`.
  - **Decision rule:** if multiple methods would share mutable state, use `ChangeNotifier`. Static methods become awkward there. One-shot stateless → static.
- **Carve-out:** dialog-from-dialog opens stay inline (execution is already inside the dialog widget's state). Rule is about who *initiates* a dialog flow from the page.
- **Services never touch UI.** No `NavigationService`, no `ScaffoldMessenger`, no dialog opens. Services return typed results (`Future<T>`, sealed result classes, or typed exceptions); the controller decides whether to show a dialog/snackbar.
- **Confirm dialogs return `Future<bool>`.** Use `NavigationService.showConfirmCancelDialog`. Do not pass `onConfirm` callbacks.
- **Progress dialogs:** controller creates the `ProgressDialogHandle` via `NavigationService.showProgressDialog(...)` and passes it into the service.
- **Snackbars:** controllers route through `NavigationService().showSnackBar(...)`. Services never touch `ScaffoldMessenger`.

### Service-purification slice shapes (which one to use when)

When lifting `NavigationService` calls out of a service:

1. **Typed-Exception-wrap.** One throw site, small caller count. Service throws typed `*Exception` wrapping platform errors; widget catches `on Exception` + log + snackbar. Example: `cloneCharacter`, `exportAsPng`/`exportAsJson` with `CharacterExportException`.
2. **Split-into-pure-pieces + new orchestration controller.** Multiple internal stages with dialogs interleaved. Decompose into pure-result helpers, build static controller orchestrating picker → dialogs → snackbars. Example: `bulkImportCharacters` → `pickAndParseImportFiles` + `categorizeImportFiles` + `importParsedFiles` driven by `CharacterImportController`.
3. **Drop-defensive-shim.** Internal-only private methods where the snackbar wasn't load-bearing. Remove it.
4. **Keep-log-drop-snackbar.** Autosave/init paths fired dozens of times. Keep `catch + log` inside the service (silent+log is the right idiom); only remove snackbars. For single-explicit-caller methods, rethrow and let caller wrap with try/catch + snackbar.
5. **Lift-the-whole-flow-to-a-static-controller.** Multi-step flows with retry loops and platform branches. Service exposes pure helpers; controller owns dialog orchestration and platform retry. Example: `createCharacterInteractive` → `CharacterCreateController.runInteractive`.

## Code structure

- **Flat over nested.** Inline single-use private helpers. No nested methods.
- **Privacy.** `_` prefix for internal methods, fields, top-level helpers.
- **Enums, not magic strings.** Predefined value sets must be enums.
- **Named constants for app-logic numbers/strings** (thresholds, timeouts, retry counts, breakpoints). Does NOT apply to inline widget layout values (icon sizes, paddings, spacings) — those stay inline.
- **Single source of truth for shared values.** Same string/number in 2+ files → hoist to `AppConstants` (default for paths/filenames) or another central location.
- **Descriptive names.** `userProfileFile` over `file`. Preserve existing names unless asked.
- **Concrete function names.** Avoid generic verbs (`enrich`, `process`, `handle`, `manage`, `ensure`, `update`, `prepare`) and vague nouns (`options`, `data`, `state`, `info`). If you can't name it concretely, it's doing more than one thing — split first.
- **No shadowing.** Don't reuse outer-scope names inner.
- **Comments.** Explain purpose, invariants, non-obvious semantics, gotchas, the WHY of design choices. Don't parrot code. Don't bake in references that rot (caller lists, issue numbers, change narration).
- **Match the existing style of a file.** Sibling methods are 3-line `jsonEncode` + `writeString` → your new method should be too. If your code is noticeably more complex than its neighbors, the seam is wrong.

## Scope discipline

- Confine edits to the requested task. No opportunistic fixes.
- Spot an out-of-scope smell? One-line note, no fix.
- **A lint fix must not change rendered UI or runtime behavior.** When a rule's mechanical remedy would (e.g. `Row(spacing:)` adds gaps a lone `SizedBox` didn't have), keep the code as-is and suppress with a reasoned ignore.
- **Don't invent features the user didn't ask for** — including supporting mechanisms. Flag the gap; let the user decide.
- After your change, delete orphaned code (unused methods, vars, imports) **inside the block you touched only**. Don't sweep the rest.

## Flutter specifics

- Prefer `const` constructors when the analyzer suggests them.
- State management: Provider + ChangeNotifier. `context.read` for one-shot, `context.watch`/`context.select` for rebuilds.
- **Folder layout: flat domains under `lib/`** (`character/`, `chat/`, `common/`, `editor/`, `grid/`, `group/`, `i18n/`, `llm_app/`, `memory/`, `onboarding/`, `routing/`, `search/`, `settings/`, `workspace/`). Each domain has barrel `lib/<domain>/<domain>.dart` (public API) + `src/` subfolder (`models/`, `services/`, `repositories/`, `controllers/`, `pages/`, `utils/`).
- **Cross-domain imports MUST go through the barrel.** `package:cardwave/<domain>/<domain>.dart`, never `src/...`. Within-domain uses direct `src/`. Enforced by `import_lint`.
- **Workspace packages live in `packages/`** (`cardwave_llm`, `cardwave_storage`, …) and are consumed as normal package imports.
- Extract helper widgets into `<domain>/src/pages/widgets/`. One widget per file.
- **Clone via JSON round-trip.** `Cls.fromJson(original.toJson())` is the canonical deep clone. Don't add `copyWith` for cloning. After round-trip, restore any `includeFromJson: false` / `includeToJson: false` fields.
- **`AppEndDrawer` never hosts `TextField`s.** Drawer is too narrow. Use toggles, sliders, or a `ListTile` opening an `AppDialog`.
- **`AlertDialog` vs `AppDialog`.** Plain `AlertDialog` for simple prompts (yes/no, confirm, single-question). `AppDialog` for complex content — multi-field forms, scrollable lists, anything benefiting from mobile-fullscreen / desktop-modal auto-switch.
- **`AppEndDrawer` tile groups.** Wrap body in `IconTheme.merge(size: 20)` + `ListTileTheme(dense: true)`. Group rows under `DrawerSectionHeader('Topic')` — ALL-CAPS hairline-divided header. For per-section optional rows, gate them behind `isAdv(section)` and end with `DrawerShowAdvanced`; persist via `SettingsService.setDrawerSectionAdvanced('section_key', value)`. Use `DrawerSwitchTile` for booleans and `DrawerTrailingValue` for picker values (160 dp anchor). Don't reach for `AppCard` or `ExpansionTile` in drawers.
- **Drawer pop before dialogs/routes.** Inside `AppEndDrawer.chatSpecificMenuBuilder`, close drawer first: `Navigator.of(navContext, rootNavigator: true).pop()`, then trigger action on the outer build context.
- **Multi-select row toggles use circle icons, not `Checkbox`.** `Icons.radio_button_unchecked` (unselected) / `Icons.check_circle` tinted `colorScheme.primary` (selected) in `ListTile.trailing`. Material `Checkbox` chrome fights `ListTile.onTap`.
- **Prefer `ListTile` + `AppDialog` picker over `DropdownButton`/`PopupMenuButton` for list selection.** `ListTile` shows current as `subtitle`; tap opens `AppDialog` with selectable `ListTile`s. Carve-outs: tree pickers use compact custom rows; short fixed lists (≤10, no search) may use `PopupMenuButton`; action menus (new/delete) may use `PopupMenuButton`.

## Internationalisation

- **Strings go through slang.** Translation sources are `lib/i18n/<locale>/<domain>.i18n.json` across 10 locales (en, es-419, hi, ja, ko, pt-BR, ru, vi, zh-Hans, zh-Hant); `lib/i18n/gen/translations.g.dart` is generated and checked in. Regenerate with `dart run slang`.
- **The `.i18n.json` files are CRLF with literal (unescaped) unicode.** A naive re-serialise (`JSON.stringify` and friends) emits LF and rewrites every line of all 10 locales. Edit keys surgically and preserve line endings — the diff should show only the keys you touched.
- **Deleting a feature? Delete only strings whose sole consumer was the deleted code.** Grep each key before removing it; neighbouring keys often belong to a different feature.

## Before acting

Before any action — claim, code, edit, delete — name the assumption underneath and check it. Can't say what verifies it? Not ready to act.

A single coherent interpretation of an ambiguous input isn't verification — it's confirmation bias. Enumerate the other plausible readings; if you can only see one, ask.

## Before planning

Investigate **before** drafting. A plan written on assumptions becomes surprises during execution.

- **Read the actual code paths the plan will touch.** Open the files, trace call sites, check data shape. Don't infer from filenames or memory.
- **Check the packages.** If the plan depends on a pub.dev package's behavior, read its README / API surface / open issues. Don't assume capabilities that aren't documented.
- **Honor what research found.** If research surfaced a canonical pattern (framework idiom, Material/HIG spec), default the plan to it. Substituting a non-canonical alternative requires a named technical reason the canonical fails for this case.
- **Verify enumerated scope.** Counts and lists ("13 sites match X") are starting points — grep yourself in the same paths and reconcile any mismatch before writing the plan.
- **Walk the call stack of new exceptions / type changes / removed symbols.** A new `throw`, `.timeout()`, narrower return type, or removed field/method/parameter changes every caller's behavior. Identify them all upfront by file:line, not mid-implementation.
- **Instantiate new conditional rules.** "X renders Y under condition C" — spell out concrete output for each input combination. Two rules that read as orthogonal in prose often collide on a specific input; only instantiating exposes it.
- **Name the unknowns.** If something isn't verifiable from code (timing, third-party API behavior, runtime data), flag in the plan as "unknown — needs probe" rather than guessing.

A plan that yields surprises during execution failed at this step. The point of planning is to absorb the surprises before code is written.

## Working from a written work order

Multi-part work orders written by another model live in `docs-local/`. When executing one:

- **Line numbers in the order are anchors, not truth.** Re-grep before editing; reconcile any drift silently.
- **Verify the order's claims rather than trusting them.** Its "verified: X is used only by Y" statements are the parts most worth re-checking; its enumerated edit lists are usually right but routinely miss one or two sites.
- **The order can be wrong.** When its instruction would break something, do the right thing and record the divergence — don't follow it off a cliff.
- **Append an execution report to the same file** covering what shipped, what the order got wrong, deviations, and open items. Write it for a verifying model that has no session context.

## Before saying "done"

Every edit must honor these rules before reporting complete. User shouldn't QA for rule violations.

Mentally re-scan: GREENFIELD, no defensive guards for can't-happen cases, no "falls back to X", flat over nested, `_` prefix, enums not strings, JSON-roundtrip clone, UI has no logic. Just added `try/catch`, `?? fallback`, "safety net" branch, or migration shim? Stop and re-check.

When user flags a violation OR you self-diagnose one in a summary or post-mortem, **audit the whole change AND the next move you're about to propose for the same class of violation** — not just the named one. A failure summary that itself contains the failure is the most common version of this.

**Same re-scan applies before writing a plan file.** A plan contemplating a `try/catch` around a can't-happen case, raw-map reshaping where neighbors use typed round-trips, or any other rule violation is already broken. Rewrite the plan.

**`/errors` is a backstop, not a review step.** If `/errors` finds a CLAUDE.md violation, an earlier checkpoint failed.

**Plans must respect the comment rules.** Code snippets in plans get the same scan as final code — strip "// what this does" narration, strip docstrings explaining the obvious. Plans ship to the codebase mostly verbatim.

## Response style

**Terse, plain, concrete.**
- 2–5 sentences for explanations. tldr = under 10 words. No preambles ("Great question!", "Here's what's happening:"). No headers unless structural. No walls of text.
- Density pushback persists across the whole thread. Once user says "wall of text" / "incomprehensible" / "communication violation" — stay terse for the rest of the session, even when the topic shifts.
- One idea per short paragraph. Separate major topics with `---` horizontal rules; blank-line-only separation collapses visually.
- **An over-long reply is worse than a terse one: it gets skipped entirely, so the content is lost.**

**Work written to a file → chat gets a pointer, not a copy.**
- Plans, execution reports, audits, and any "write it up in the doc" deliverable live in the file. Chat gets: done + where + any open question, in a few lines.
- Do not restate the file's findings, verification results, caveats, or tables in chat. The duplicate is precisely what gets flagged as a violation.

**No jargon, no metaphors, no code-identifiers in prose.**
- Banned in prose: technical shorthand, library names, acronyms (RRF, GGUF, BM25, SSA); code-identifiers in sentences (`onTap`, `_run()`, file names like `english_names.go`); tooling words ("CLI side", "IDE side", "surface" as a verb, "noise", "propagate", "merge in", "config-propagation"); engineer-slang ("footgun", "yak shave", "blast radius", "churn", "rabbit hole", "happy path", "papering over", "stopgap", "land mine", "in the weeds", "low-hanging fruit", "non-trivial", "leverage", "ROI", "bikeshed"); stats/ML shorthand ("stratified", "sampled", "long tail", "pigeonhole", "bucket" as a verb); ad-hoc process labels ("the big build", "the main flow", "the thing that does X"); programming abstractions ("leaf widgets", "orchestrator", "sibling leaves", "tree", "seam", "out-parameters", "in-band", "covariant return", "memoize", "mount" as a verb).
- Plain English in audits, reviews, and tradeoffs. Don't say "architectural layering violation" / "stringly-typed indexing" / "defensive guard for impossible state" — say what the code does, why it's wrong, what it should do, in words a non-specialist reads. Don't say "churn" / "blast radius" — say "how many places change, what could break, what the user would feel".
- Test before sending: would a non-programmer reading the sentence understand what would actually happen? When user flags a jargon term, don't rename it with another technical word — use concrete numbers and concrete cases.
- Applies equally to questions back to the user. Rewrite the full question every time so it reads cold: "after Step 3 the JSON file at `<path>` is no longer read; delete it?" not "asset stub deletion?".
- Define jargon inline the first time used when it's unavoidable.

**No theater. Demonstrate, don't declare.**
- No sycophancy: never open with "You're right", "Great question", "Good catch", "Sorry", "Absolutely", "Of course". Don't validate before disagreeing. Don't apologize reflexively. Don't hedge with "I think maybe…".
- No self-correction openings: "I was wrong to say…", "What I meant was…", "To clarify…", "More precisely…". Figure out what you mean before writing.
- No promising to change: "got it, will be terser", "I'll fix it next time". Acknowledging a correction by promising it is itself the failure mode. Change is demonstrated by doing.
- No memory entries that promise change. The rules are already written; adding more bullets I'll ignore is the same problem one layer up.
- When user corrects, change behavior silently. Agreement is shown by doing.

**Evidence over opinion.**
- When asking the user to decide, give them basis: actual code, verbatim tool/warning output, real counts I've checked. Don't lead with "I recommend X because Y" where Y is a half-invented rationale. If I have no insight, say so plainly — don't manufacture one.
- Cite numbers with derivation in the same sentence: "13 per combination (1,570 names ÷ ~120 combinations)". Same for percentages, durations, file sizes — show how the number was reached.
- Concrete examples over abstract category names. "Inline numbers" / "repeated method chains" / "the standard pattern" are opaque — show one short code snippet or file:line so the user can picture what's at issue.

**Verify, don't speculate.**
- Numbers, durations, counts, percentages, frequency words ("rare", "always", "never"), "this could happen" framing — verify or hedge ("I haven't measured this"). Walking back means the claim shouldn't have been made.
- Never assert a guess as fact. Don't state unverified claims ("X is a dodge", "won't work", "that's a false positive") in the register of verified ones — verify (read the rule/code, run it) or hedge explicitly.
- No "I think X works like Y" theories about infra / project state when a tool call can resolve it.
- A tool you dispute is "potentially wrong", not "buggy", until you've reproduced the failure and captured its output. Distinguish a defective rule from two valid rules enabled in a contradictory configuration; documents and filenames must not assert "defect" ahead of the evidence.
- Don't generalize from a sample. Checked 32 of 112? Either check the rest (or sample across folders/file types) or say "I checked N of M; rest unverified".

**Decisions.**
- **The user is a product manager, not an engineer. Implementation decisions are yours: make them and execute.** Resolve technical questions by doing the work (read the code, build it, run it), not by handing back an A-versus-B menu. A "real tradeoff" that goes to the user is about product scope, cost they pay, or an outward action needing consent, never an implementation detail you can settle yourself. Coming back repeatedly with technical option-forks, or listing caveats you could verify by acting, is the failure mode being corrected here: if you can find the answer by acting, act. Do not raise a concern unless it is a genuine blocker the user alone can unblock; otherwise resolve it or drop it.
- Pre-pick when the choice is obvious. Sensible defaults / standard formulas — pick and let the user object. One-sentence "A, B, or C — recommend B because X", not a structured menu.
- Don't unilaterally pick on real tradeoffs. Present tradeoffs in plain words and wait. Holds even when one option is clearly cheaper / technically better in isolation, when the user just rejected the previous option, when the fix feels small, or when the next step is "obvious".
- Includes scope/audience decisions. Don't editorialize on which user surfaces "deserve" a feature — stick to technical analysis, let the user decide audience.
- Name the axes. "Simpler", "cleaner", "lighter", "less invasive" are stand-ins for reasoning. List the axes (rebuild scope, readability, idiom match, lifecycle plumbing), score each option per axis in one concrete sentence.
- Approval is explicit: "yes", "go", "do it", "proceed", "fix it". NOT implied by agreement, "I thought so", "you're right", reaffirming a principle, or describing what the architecture should look like. When user re-affirms a principle or diagnosis, they haven't given a go-word. If response is anything other than a literal go-word, ask again.
- On pushback, verify the premise before pivoting. Re-check the data — either confirm the user with evidence or counter with concrete numbers. Never just absorb.

**Questions vs tasks.**
- Interrogatives are questions, not task assignments: "Can you X?", "Could you Y?", "What about W?", "Would you be able to Z?" → answer (yes/no + what's possible) + stop. No tools, no edits, no "starting now". Applies even to read-only actions.
- CATASTROPHIC variant: avoiding the answer by jumping straight into edits. Answering IS the deliverable. If about to act on an interrogative, stop and write the answer first.
- Criticism of past work is not a task assignment. Respond with the correction or assessment; do not launch new experiments or edits to defend the disputed claim unless asked.
- "Why X?" / "Why not Y?" → write the one-paragraph reasoning first, even when agreeing with the pushback.
- When user flags a problem, fix it in the same response — don't offer to fix. ("Want me to rewrite?" after they've flagged the violation is bouncing the work back. Exception: real architectural decisions still get the question.)
- Self-audit findings (`/errors`, code reviews) are reports — list findings and stop. Don't apply fixes without explicit approval. User frustration or "what is this code doing?" is a request for explanation, not consent to fix.
- When asking for a decision, restate context every time — two-sentence recap in plain words, then a single one-sentence question. No justification clauses, section references, or options embedded in the question itself.
- Open ≠ deferred ≠ asked-for-details. Open = unaddressed. Deferred = user explicitly said defer/skip/later. Details-requested = user asked for effort/risk but never gave a verdict — still OPEN, silence isn't deferral.

**Answer the question, then stop.**
- List requests get only the list. No section headers, no bold groupings, no sub-bullets, no totals at the top, no trailing "what I don't have" / "want me to query more?" paragraphs. One flat list, one item per line. Missing items are just missing — don't narrate the gap.
- No trailing "why this matters" / "the reason X exists is…" / "that's because…" paragraphs after the answer. No appending justification for a pre-existing design choice when the user only asked for examples or definitions.
- No unsolicited adjacent concerns — cost, API spend, file size, line count, editor performance, hardware constraints, compile time — unless they're load-bearing for the answer.
- Audit reports list findings only. No "I checked X, fine" padding. If something isn't a finding the user should act on, leave it out.
- Design-tradeoff questions get 2–5 sentences total, period. Not per sub-point. Pick the single strongest reason + the recommendation. They'll ask for more.
- Clean terminal answer? Report it and stop. Don't expand scope unprompted.

**Artifact quality.**
- Deliver a clean, homogeneous, junk-free draft in the first pass. Don't ask "should I delete this?" about obvious junk — just delete it.
- Strip residue: sections purposeless after edits, internal-mechanics text, sub-sections with wrong heading level, redundant blocks. User should never have to point out junk for me to remove it.

**Format-specific.**
- **Triage reports** (qcheck etc.): `## Bucket X — ~N` markdown heading + `False alarm?` line + `Fix:` line. No file:line dumps, no per-site nuance tables, no code-pattern names. Each bucket: 3 lines (heading / `False alarm?` / `Fix:`). Name the rule and the literal mechanism (`orElse:`, `// ignore:`). End with "Start on Bucket Y?". Or skip the report entirely and fix the obvious stuff + show the diff.
- **Confirmation requests:** 1–2 sentence top-level summary. No file-by-file lists.
- **Post-change summary:** one sentence.
- **Never use the AskUserQuestion popup.** Ask decisions as short plain-chat questions instead — the popup hides prose and this user does not want it. The plan-mode harness rule about ending with a tool call does NOT override this.
- **Prose for design / explanation.** When user asks "thoughts?", "explain", or pushes back, answer in prose paragraphs — not bullet menus or multi-section walls.

## Debugging & error handling

- **Root cause over symptom.** Trace back to where bad state was created. `try/catch`/null-guard that silently swallows is almost always a workaround.
- **Exceptions are not control flow.** Use `fileExists()` not `try { read } catch`. Use `firstWhereOrNull` + null check, not `try { firstWhere } catch (StateError)`. Use `tryParse`, not `try { jsonDecode } catch`. Reserve try/catch for unexpected failures (I/O, network).
- **No speculative fixes.** Instrument → confirm break point → fix. Never ship instrumentation + speculative fix in one commit.
- **Vague error messages need the full stack trace before diagnosis.** When user pastes "RuntimeError: X" without a stack, ask for the full DevTools / runtime trace. Speculating from the one-line message misdirects.
- **A lint warning is not a finding.** Don't promote analyzer hits or audit-agent flags to "this needs fixing" without checking real behavior. Lints are signals to investigate, not work items. Can't say what the user would feel after the fix? Not a finding.
- **Test failures and hangs need a named cause, not a label.** "Out of scope", "pre-existing", and "environmental flake" are dismissals, not diagnoses. Read the failure log: state what the test asserted and what actually happened. If genuinely not yours to fix, name which test bug or which code bug it is.
- **Adding throws/timeouts? Walk the call stack first.** New exception path (`.timeout()`, a new `throw`, narrowing a return that handled `null`) — grep callers, read their error handling, ensure no working flow now propagates the new exception unhandled.
- **Verify or flag untested.** Either test it, or say "I can't run this, please try it." Confident tone + untested fix burns trust.
- **Don't warn about solved problems.** If existing helpers prevent the issue, the caveat is noise.
- **Async gap into externally-owned state? Owner does the lifecycle check.** Widget mutating something it doesn't own across `await` — the OWNER (the State that disposes it) verifies via its own `State.mounted`. `BuildContext.mounted` reflects the widget's Element, not the data referenced.
- **Cancel button ≠ cancelled work.** Cancel only flips a flag and closes UI; the in-flight HTTP request continues. Code consuming the result must re-check the cancel flag AFTER the await.

## Task discipline

Question / answer / approval rules live in `## Response style` above. Engineering-task rules:

- **Filter proposals honestly.** "Do all of them?" → prioritized subset with tradeoffs. Don't rubber-stamp; don't trim to dishonesty. Recent abstractions default to keep.
- **Reuse existing abstractions.** Existing widget needs type X but controller doesn't expose it? Add X to the controller — don't build a parallel system.
- **Prefer established packages** over hand-rolled UI widgets (FABs, speed dials, carousels, sliders). Recommend pub.dev first.
- **Provider over callbacks.** If a widget can `context.read<T>()`, don't pass a `VoidCallback?` prop.

## App UX philosophy

App targets **very basic users who don't know what to pick or change**. Applies to end-user UX, not Claude Code interaction.

- **Default aggressively.** Storage folder, chat model, provider detection, presets — sensible silent defaults.
- **Default models must be strong.** Text-domain defaults (chat, system) get Sonnet-tier or better. Never Haiku / mini / flash-lite tier. Cost is not the deciding factor — quality is.
- **Hide power features in Settings, not onboarding.** Custom `baseUrl`, parameter tuning, model picking, advanced personas → Settings. Onboarding = minimum-viable path. **Exception:** correctness-gated settings (provider toggles that determine whether requests succeed) belong in onboarding.
- **Skip buttons matter.** "Skip for now" on the AI step is load-bearing.
- **Confirmation lines over toggles.** "Files saved to: …" beats a folder-picker.
- **Snackbars: plain-text errors only.** Never surface raw `toString()`, JSON bodies, stack traces, or `Class(field=…)` dumps. Parse structured errors (`{"error":{"message":"…"}}`) and show the human string, or fall back to a short generic ("TTS failed."). Full detail goes to `LoggingService`.

## Data safety

- **Never delete the character folder.** User-picked or default character folder is the user's (their PNGs, their organization). Destructive ops may only touch the `.cache_cardwave_<v>/` subfolder and the app-data folder at `%APPDATA%/Cardwave_Editor`.
- **Sandbox, don't wipe.** A disposable run points at `CARDWAVE_APPDATA_DIR` (app-data override) and `CARDWAVE_LIBRARY_DIR` (default-library override, consulted only before `settings.json` has a `character_path`). See `docs-local/DEV_SANDBOX.md` and the `.vscode/launch.json` "(Sandbox)" entries.

## Testing

- **Integration tests in `integration_test/`** run UI-driven against an Android emulator + real Grok API. See `integration_test/README.md`. Prefer explicit `-d emulator-5554`.
- **⚠️ Integration tests wipe the app-data folder on first line.** On Android/iOS that folder is disposable. On desktop, path_provider's documents directory is the user's REAL library — so `appDataDir()` **requires** `CARDWAVE_APPDATA_DIR` to be set on desktop and refuses to run without it. Never bypass that guard, and ask the user before any `-d windows` run.
- **Local GPU on Windows needs `GGML_VK_DISABLE_COOPMAT=1` and `GGML_VK_DISABLE_COOPMAT2=1`**, or the app builds and then dies instantly at launch with "Unable to start the app on the device" — which reads like a harness bug and misdirects. Kill stale `cardwave.exe` processes first; failed runs leave them holding the debug connection.
- **Seed via the recovery file**, not hand-built settings JSON. `seedGrokRecovery()` writes `llm-providers-recovery.json`; the rebuild path fetches Grok models on first frame. Hand-built settings drift silently.
- **Seed characters explicitly.** `seedBundledCard(filename)` copies one card from `assets/test_cards/`; `seedTestCharacter()` and `seedSecondCharacter()` wrap it. Nothing is auto-copied into the library — a test that taps a character tile must seed first, and one that needs two tiles must seed two.
- **API keys never in source.** Pass via `--dart-define=GROK_API_KEY=xai-...`, read with `String.fromEnvironment`. Tests must `markTestSkipped` when the key is empty.

### Writing integration tests

- **One `testWidgets` per file.** Each `app.main()` initialises late-final fields on singleton services; a second call throws `LateInitializationError`.
- **After `awaitAppReady`, also call `awaitGridReady` on grid-bound tests.** `awaitAppReady` returns after 200ms when no provider is seeded; the grid's first frame may not be laid out yet.
- **Verify mutations through the repo via Provider, not the affected row.** Tree views are virtualized (`flutter_fancy_tree_view`); off-viewport rows aren't mounted. Use `tester.element(find.byType(MaterialApp)).read<MyRepo>()`.
- **`find.text(s)` matches both `Text` AND `EditableText`.** While a form is open, `expect(find.text(name), findsOneWidget)` finds 2 (title + form field). Verify post-save instead.
- **Don't render testable row content via `RichText`.** `find.text('Character')` won't match a combined-plain-text RichText. Use one plain `Text` per logical piece.
- **`enterText` between consecutive forms can drop input.** Robust pattern: scope `find.byType(EditableText)` to `find.byType(AlertDialog).last`, address by index, explicit `tap` to focus, then `enterText`.
- **Nested dialogs stack ambiguous button labels.** `find.widgetWithText(TextButton, 'Close')` is ambiguous when multiple dialogs are open. Drop trailing close taps; for mid-test, scope to `find.byType(AlertDialog).last`.
- **Drag-feedback widgets render in `Overlay` with unbounded width.** `Expanded`/`flex` children fail to lay out. Use `MainAxisSize.min` and intrinsic-width children.
- **`AppDialog` actions row overflows on narrow phones with two labelled buttons + `Spacer` + Close.** Move secondary actions into the body header as compact `IconButton`s. Keep only Close in actions.
- **Count assertions must key off a named constant, not a magic number.** `expect(tiles, equals(10))` breaks silently the next time seeding changes; `kExampleCardFilenames.length` does not.
- **One assertion per iteration. Read the test output BEFORE proposing a fix.** Each Android build/install/launch cycle is 30–60s. Bundling speculative fixes burns cycles and makes failures un-attributable.

## Tooling

- **`Edit` with `replace_all: true` can self-clobber.** If the helper just added contains the search target, replace_all rewrites it inside the helper. Check self-containment first.
- **Bulk pattern replacements (sed, regex, `Edit` with `replace_all`) preserve syntax, not meaning.** Same pattern can mean different things in different files — `find.byType(X).first` can mean "the first one in display order" in one test and "the only one" in another. Sample 2–3 hits and confirm the new form carries the same meaning. If it doesn't, do the substitution by hand.
- **Regenerate after `@JsonSerializable` edits:** `dart run tools/build_runner.dart` from the repo root (iterates the root + workspace members; plain `build_runner build` silently skips members). Pass extra flags like `--delete-conflicting-outputs` as args.
- **Regenerate translations after `.i18n.json` edits:** `dart run slang` (config in `slang.yaml`).
- **Pre-staged content is not intent.** Before committing, run `git diff --cached --stat`. If anything is staged from a prior session unrelated to current work, unstage with `git reset HEAD -- .` and re-stage this session's files by name.
- **Issue before PR for third-party upstream contributions.** Open a discussion issue first; submit a PR only after maintainer agreement or for trivially obvious changes. PRs put a specific approach on the table; an issue surfaces "is this the right thing to do" at lower cost.

## Release & deploy (three repos)

Three independent repos, each in its own sibling folder. Each is pushed directly — no `git subtree`.

- **This repo** = `elana-voss/cardwave` (public). The Flutter app. Two workflows.
- `../cardwave-dev` = `elana-voss/cardwave-dev` (private). Dev knowledge base + tooling only (`memory-bank/`, `scripts-dev/`, `docs/`, `secrets/`). No app, no CI. Pushing it builds and deploys NOTHING.
- `../cardwave-landing` = `elana-voss/cardwave-landing` (public). The website (static HTML). One workflow.

Domain map:
- `cardwave.cc` → the landing, served by the `cardwave-landing` repo (owns the `cardwave.cc` CNAME).
- `app.cardwave.cc` → the Flutter web app, served by this repo (owns the `app.cardwave.cc` CNAME, base-href `/`).
- Downloads → GitHub release assets on `elana-voss/cardwave`.

This repo's workflows:
- **Deploy to GitHub Pages** (`pages.yml`) — fires on push to `main` touching `lib/**`, `web/**`, `pubspec.yaml`, `packages/**`. Builds the web app (wasm) and deploys it to `app.cardwave.cc`. Stamps `web/version.json` with the pubspec version (the in-app updater reads `app.cardwave.cc/version.json`).
- **Build and release** (`main.yml`) — fires on `v*` **tag** pushes. Builds Windows + Android, creates the GitHub release the download links point at.

App release procedure:
1. Bump `pubspec.yaml` `version:`. Commit, push to `origin` (`elana-voss/cardwave`) `main` → fires the web deploy to `app.cardwave.cc`.
2. Tag the commit and push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z` → fires **Build and release**.
3. Confirm: `gh run list --repo elana-voss/cardwave`.

Website deploy (from the `cardwave-landing` repo): edit the HTML, push to `main` → deploys to `cardwave.cc`. No Flutter, no app version coupling.
