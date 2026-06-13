# Macro engine (`UtilsPrompt.replacePlaceholders`)

Reference for the `{{...}}` placeholder substitution engine used when building
prompts and greetings. Documents what is implemented today and where it diverges
from SillyTavern.

Reference spec: <https://docs.sillytavern.app/usage/macros.md>

## Where it lives

Single source: `app/packages/cardwave_llm/lib/src/utils/utils_prompt.dart`,
exported from the package barrel `cardwave_llm.dart`. The app re-exports it
through `app/lib/common/common.dart` (`export ... show UtilsPrompt`), so app code
keeps importing it from the common barrel unchanged.

It lives in the package rather than the app because `cardwave_llm`'s own image
and video prompt builders need it, and a package cannot import app code.

## Call sites and the context each passes

| Caller | Local vars | Global vars | `trackingId` |
|---|---|---|---|
| `ChatPromptBuilder` (system / post-history / depth / injected / history / examples) | yes | yes | yes (`'system'`, etc.) |
| `ChatService` first message + greetings | yes (`session.localVariables`) | yes (`settings.globalVariables`) | yes |
| `ImageGenerationService` / `VideoPromptBuilder` | yes (`request.*`) | yes | yes (per mode) |
| `GroupPromptService.getInitialGroupGreeting` | **no** | **no** | **no** |

Consequence of the last row: in the group-greeting path, variable macros resolve
to empty and `{{pick}}` degrades to `{{random}}`.

Local variables persist per chat (`ChatSession.localVariables`); globals persist
in `AppSettings.globalVariables`.

## Supported macros

| Macro | Behavior |
|---|---|
| `{{char}}`, `{{bot}}` | Character name (nickname preferred where the caller passes one), trimmed. |
| `{{user}}` | Persona / user name, trimmed. |
| `{{time}}` | Local time, `DateFormat.jm()` (matches ST's `LT`, e.g. `5:08 PM`). |
| `{{time_UTC±H}}` / `{{time::UTC±H}}` | Current time at a whole-hour UTC offset (e.g. `{{time_UTC+2}}`, `{{time_UTC-5}}`). |
| `{{date}}` | Local date, `DateFormat.yMMMMd()` (matches ST's `LL`, e.g. `June 13, 2026`). |
| `{{random::a::b::c}}` / `{{random:a,b,c}}` | Random option; re-rolls on every render. |
| `{{pick::a::b::c}}` / `{{pick:a,b,c}}` | Stable option, keyed by `trackingId` + position. Falls back to random when no local vars / `trackingId`. |
| `{{roll::NdF}}` / `{{roll::N}}` | Dice. `NdF` sums N rolls of an F-sided die (N capped at 100, F floored at 1). Flat `N` rolls 1..N. Defaults: count 1, faces/max 20. |
| `{{getvar::name}}` | Read local variable (empty if unset). |
| `{{setvar::name::value}}` | Set local variable; emits nothing. |
| `{{getglobalvar::name}}` | Read global variable. |
| `{{setglobalvar::name::value}}` | Set global variable; emits nothing. |
| `{{newline}}` / `{{newline::N}}` | One newline, or N (clamped 1..100). |
| `{{space}}` / `{{space::N}}` | One space, or N (clamped 1..100). |
| `{{noop}}`, `{{hidden_key}}`, `{{comment}}` | Empty string. |
| `{{reverse::text}}` | Reverses the argument. |
| `{{// comment}}` | Comment (leading `//`); emits nothing. |

### Variable shorthand

`{{.name}}` = local, `{{$name}}` = global. Name charset is `[a-zA-Z0-9_]+`
(no hyphen, so `{{.n--}}` reads as decrement, not a variable named `n--`).

| Form | Behavior |
|---|---|
| `{{.name}}` | Read. |
| `{{.name = value}}` | Set; emits nothing. |
| `{{.name++}}` / `{{.name--}}` | Increment / decrement (numeric, defaults 0); emits the new value. |
| `{{.name += value}}` | Numeric add, or string append when either side is non-numeric; emits nothing. |
| `{{.name -= value}}` | Numeric subtract (no-op if non-numeric); emits nothing. |
| `{{.name \|\| fallback}}` | Value if truthy, else fallback. |
| `{{.name ?? fallback}}` | Value if set, else fallback. |
| `{{.name \|\|= value}}` | Assign if falsy; emits resulting value. |
| `{{.name ??= value}}` | Assign if unset; emits resulting value. |
| `{{.name == value}}`, `{{.name != value}}` | String compare → `"true"`/`"false"`. |
| `{{.name > value}}`, `>=`, `<`, `<=` | Numeric compare → `"true"`/`"false"` (`"false"` if either side non-numeric). |

Truthiness (`||`, `||=`): empty, `false`, `0`, `off`, `no` are falsy; everything
else truthy.

### Conditionals

`{{if cond}}…{{else}}…{{/if}}` keeps one branch based on whether `cond` is
truthy. `{{else}}` is optional; blocks nest; `!` before the condition inverts it.
Spacing is lenient (`{{ if x }}`, `{{ /if }}`), and a block may be inline or span
multiple lines.

The condition may be a variable shorthand (`{{if .flag}}`, `{{if !$banned}}`), a
nested macro (`{{if {{getvar::flag}}}}`), a comparison (`{{if .score > 3}}`), or a
plain value. Truthiness uses the same rule as above. The untaken branch is dropped.

Only the kept branch is rendered, so a `{{setvar}}` (or any other side-effecting
macro) placed inside the dropped branch does not run.

## Parsing rules

- Separator precedence: `::` first, then `:`, then a single space. So
  `{{setvar::x::5}}`, `{{setvar:x:5}}`, and `{{setvar x 5}}` all parse.
- Command token is lowercased; unknown commands are **emitted verbatim** (see below).
- The text is rendered in a single left-to-right pass: at each `{{...}}` the
  inner macros resolve first, then the macro applies (mutating variables in
  place), then the walk continues past it. So a variable written earlier is
  readable later in the same text, and a stored value that itself contains a
  macro (e.g. `{{char}}`) is expanded when read.
- Regex is `\{\{([^{}]+)\}\}`; macro bodies cannot themselves contain braces.

## Not implemented

Everything in the reference spec that is not in the table above falls through to
the default branch. These do **not** resolve:

- **Card fields:** `{{description}}`, `{{personality}}`, `{{scenario}}`,
  `{{persona}}`, `{{charPrompt}}`, `{{charInstruction}}`, `{{charDepthPrompt}}`,
  `{{charCreatorNotes}}`, `{{charVersion}}`, `{{mesExamples}}`,
  `{{mesExamplesRaw}}`, `{{charFirstMessage}}` (and `::index`), `{{original}}`,
  `{{charPrefix}}`, `{{charNegativePrefix}}`.
- **Group:** `{{group}}`, `{{groupNotMuted}}`, `{{charIfNotGroup}}`, `{{notChar}}`.
- **Chat / message:** `{{lastMessage}}`, `{{lastMessageId}}`,
  `{{lastUserMessage}}`, `{{lastCharMessage}}`, `{{firstIncludedMessageId}}`,
  `{{firstDisplayedMessageId}}`, `{{lastSwipeId}}`, `{{currentSwipeId}}`,
  `{{allChatRange}}`, `{{summary}}`, `{{input}}`.
- **Date / time extras:** `{{weekday}}`, `{{isotime}}`, `{{isodate}}`,
  `{{datetimeformat ...}}`, `{{idle_duration}}`, `{{timeDiff::a::b}}`.
- **Named variable math:** `{{addvar}}`, `{{incvar}}`, `{{decvar}}`,
  `{{hasvar}}`, `{{deletevar}}` and the `...globalvar` variants. (The shorthand
  operators above cover the same operations, but these named forms do not.)
- **Environment:** `{{maxPrompt}}`, `{{maxContextTokens}}`,
  `{{maxResponseTokens}}`, `{{model}}`, `{{isMobile}}`, `{{lastGenerationType}}`,
  `{{hasExtension::name}}`.
- **Prompt / instruct:** `{{systemPrompt}}`, `{{defaultSystemPrompt}}`,
  `{{authorsNote}}`, `{{charAuthorsNote}}`, `{{defaultAuthorsNote}}`, all
  `{{instruct*}}` sequences, `{{chatSeparator}}`, `{{chatStart}}`,
  `{{reasoningPrefix}}`, `{{reasoningSuffix}}`, `{{reasoningSeparator}}`.
- **Text utils:** `{{trim}}`, `{{banned::word}}`, `{{outlet::key}}`.

## Known divergences and errors

1. **Unknown macros leak into the model prompt.** The default branch returns the
   original `{{...}}` text, so every unimplemented macro above is sent to the LLM
   verbatim. A card or preset template that uses, say, `{{description}}` or
   `{{trim}}` emits the literal braces into the context.

2. **Most date/time variants beyond `{{time}}` / `{{date}}` / UTC offset leak.**
   `{{weekday}}`, `{{isotime}}`, `{{isodate}}`, `{{datetimeformat ...}}`,
   `{{idle_duration}}`, and `{{timeDiff::a::b}}` are unimplemented. (`{{time}}`
   and `{{date}}` match ST's `LT` / `LL` output, and the UTC-offset form now
   resolves — see the supported table.)

3. **Variable math is asymmetric.** Shorthand (`{{.x++}}`, `{{.x += 5}}`) works,
   but the named equivalents (`{{incvar::x}}`, `{{addvar::x::5}}`) leak. A card
   written against the named forms silently breaks.

4. **`{{pick}}` stability is positional, not content-hashed.** ST keys a pick on
   its option list and position; here it is keyed by `trackingId` plus the
   left-to-right order in which pick macros are encountered. Adding or reordering
   a pick earlier in the same text shifts the index and can reassign an
   already-saved choice. In the group-greeting path (no `trackingId`) pick is
   just random.

5. **`{{random}}` / `{{pick}}` comma-splitting only applies in single-colon
   form.** An option that legitimately contains a comma, written single-colon,
   is split into separate options.
