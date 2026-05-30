# cardwave_nodes

A chat-side engine for character interiority. Tracks per-chat state (emotions,
goals, scene, flags, event log) and decides what scripted beats fire each turn.
Pure logic plus an LLM-backed director. No UI, no file IO, no settings.

## Two systems with different jobs

**The firing engine** picks scripted beats. Each beat (a "node") is authored on
the character card. It has a probability, a predicate, a cooldown, and a
narrative payload to slot into the next reply. The engine is pure code, no LLM.
Use nodes for things you want to happen reliably under specific conditions ("if
joy is high enough, she finally smiles back").

**The director** is one LLM call per turn that reads what just happened and
adjusts state. It returns small numeric changes (emotion deltas), short
authorial notes ("she is still cool toward him, softening only slightly"), and
event-log entries. It cannot fire nodes, change scenes, or change phases. Those
are the engine's job.

Per turn the order is:

1. Pool ticks (countdowns advance).
2. Engine rolls nodes, fires winners, applies effects to state.
3. Host assembles the actor's prompt, including the scene block, state slice,
   any sticky directives, and any payloads fired this turn.
4. Actor LLM writes the character's reply.
5. Director LLM reads the reply and nudges state for next turn.

## A node, in JSON

Nodes live in the card's SillyTavern v3 `extensions.cardwave_nodes` block:

```json
{
  "extensions": {
    "cardwave_nodes": {
      "authored_nodes": [
        {
          "id": "first_compliment",
          "origin": "authored",
          "type": "characterBehavior",
          "trigger_prob": 0.4,
          "delay": 0,
          "cooldown": 6,
          "sticky": 0,
          "alive": -1,
          "scope": "session",
          "predicate": "character.alice.emotion.joy > 0.5",
          "narrative_payload": "She finally returns the smile.",
          "effects": {
            "emotion_deltas": {
              "alice": { "trust": 0.05 }
            }
          }
        }
      ],
      "emotion_baseline": { "trust": 0.4 },
      "initial_goal": "meet the stranger",
      "initial_scene": {
        "location": "tavern",
        "time_of_day": "evening"
      }
    }
  }
}
```

Field meanings:

- `trigger_prob`: base roll, 0.0 to 1.0. The engine adds a pressure bonus per
  pool so a beat that has not fired in a while becomes more likely.
- `delay`: turns to wait before becoming eligible. 0 means "right away". -1 is
  treated as 0.
- `cooldown`: turns between firings. 0 means no cooldown. -1 means no cooldown.
- `sticky`: turns the narrative payload keeps appearing in the prompt's
  "Lingering" block after firing. 0 means one shot, -1 means permanent.
- `alive`: turns to live in the pool before being removed. -1 means forever.
- `scope`: `phase`, `scene`, `session`, or `oneShot`. Determines when the node
  is removed (e.g. `scene` nodes vanish at the next scene transition).
- `type`: `characterBehavior`, `environmental`, `event`, or `pacing`. Each
  type is its own pool, and at most one node per pool fires per turn.
- `predicate`: a boolean expression over state. See "Predicates" below.
- `narrative_payload`: the line that gets slotted into the actor's prompt.
- `effects`: optional state changes applied when the node fires.

`spawns` (not shown) lets a fired node drop new nodes into the pool, useful for
multi-beat sequences.

## Authoring guide (editor UI)

The host app (cardwave) ships an editor for this block under
**Character editor → Nodes panel**. The editor reads and writes the same
`cardwave_nodes` JSON above; you never hand-edit the JSON.

### Engine seed (top of the panel)

The session starts with whatever you set here. All four fields are optional.

- **Initial goal** — a short sentence saying what the character is trying to do
  at the start of the chat (e.g. *"meet the stranger at the tavern"*). Read by
  the actor LLM as part of its prompt; predicates can also read it as
  `global.goal`. Cleared when a fired node's "Goal change" effect overwrites it.
- **Emotion baseline** — starting value (chip + slider) for any emotion you
  want set above zero at session open. Anything you don't list defaults to
  zero. Use sparingly — the director will move these on every turn.
- **Initial scene** — location, time of day, comma-separated lists of
  "Present" entities and "Sensory hooks". These seed `global.scene.*` and feed
  into the actor's scene block in the prompt.

### The node list

Below the engine seed, the panel shows one row per authored node:

```
  ≡  node_1780140681326   characterBehavior  session   🗑
     character.alice.emotion.joy > 0.5
```

Drag handle reorders (display only; firing order is not affected). The trash
icon deletes the node. Tap the row to open the per-node editor.

The **Add Node** button creates a fresh node with sensible defaults
(`triggerProb: 1.0`, `predicate: "true"`, `scope: session`, all countdowns
at 0 except `alive: -1`).

### The per-node editor

**Type** (`characterBehavior` / `environmental` / `event` / `pacing`)
The pool the node belongs to. Each pool fires *at most one node per turn*, so
two character-behaviour nodes that win their roll on the same turn don't both
fire — one is chosen. Rough guide:

| Type | Use for |
|---|---|
| `characterBehavior` | beats the character performs (a smile, a comment, a withdrawal) |
| `environmental` | beats the world produces (rain starts, a stranger walks in) |
| `event` | discrete happenings, especially rare one-shots |
| `pacing` | deliberate quiet beats (a beat of silence, a slow look) |

**Scope** (`phase` / `scene` / `session` / `oneShot`)
*When* the node leaves the pool, independent of `alive`:

| Scope | Removed when |
|---|---|
| `oneShot` | the node fires once |
| `scene` | the engine marks a scene transition |
| `phase` | the engine marks a phase transition (scene ↔ sequel) |
| `session` | never (until `alive` runs out, or the chat ends) |

**Origin** (`authored` / `generated`)
`authored` means you wrote it. `generated` means the director LLM produced it
during a chat. Leave at `authored` for nodes you write — only change if
you're capturing a director-generated node into the card.

**Trigger prob** (slider + numeric field, 0.0–1.0)
Base probability of firing on any turn where the node is eligible. The engine
adds a small pressure bonus when the pool has been quiet (up to +0.3). For an
"almost certainly fires when eligible" beat use 0.8–1.0; for a "sometimes
flavour" beat use 0.2–0.4.

**delay / cooldown / sticky / alive** (numeric field + helper line below)
All four are *turn counts*. `-1` is a sentinel — its meaning differs per field
(shown below the field as helper text in the editor):

| Field | What 0 means | What `-1` means | "Set to never" button |
|---|---|---|---|
| **delay** | eligible immediately | acts as 0 | — |
| **cooldown** | no cooldown | no cooldown (same as 0) | sets `-1` |
| **sticky** | one-shot (payload only appears the turn it fires) | payload appears forever | sets `-1` |
| **alive** | removed next tick | stays in the pool forever | sets `-1` |

Authoring rules of thumb: `cooldown` matters when `triggerProb` is high —
without it the beat repeats every turn. `sticky` makes the beat "stay in the
character's head" for a few turns (it shows up under "Lingering" in the actor
prompt).

**Predicate** (multi-line text)
Gate the node behind a boolean condition over state. Default is `true` (always
eligible). Live problems list under the field flags syntax errors or unknown
field references. Full reference under **Predicates** below.

**Narrative payload** (multi-line text)
The exact line that lands in the actor LLM's prompt when the node fires. Write
it as a directive the actor will follow — *"She finally returns the smile."*
rather than *"smile event"*. If `sticky > 0`, this line will also appear in
later turns' "Lingering" section.

**Effects** (collapsible categories, one per effect type)
Optional state changes the node applies when it fires. Empty by default.

- **Emotion / Physical / Relationship deltas** — small numeric nudges per
  field (slider + numeric, range `-1.0` to `+1.0`). The character is the
  card's own id; multi-character target is preserved in the schema for
  future use but hidden from the UI.
- **Knowledge writes** — fact-teaching. Each entry has a topic, a value
  (string / number / bool — pick the type from the dropdown), and a
  confidence (0–1). Stored under `character.<id>.knowledge.<topic>`.
- **Flag set** — key/value pairs into `character.<id>.flags`. Useful for
  one-bit state ("met_stranger", "knows_password").
- **Scene & flow** — one-shot transitions:
  - *goalChange* (string) replaces `global.goal` (empty clears it).
  - *phaseChange* (none / `scene` / `sequel`) flips `global.phase`.
  - *sceneTransition* (toggle) tells the engine the next director pass should
    seed new scene context.

**Spawns** (mini list at the bottom)
Child nodes that get dropped into the pool when this one fires. Tap a spawn
row to push another full editor onto the navigation stack (recursive — a
spawn can have its own spawns). The app-bar subtitle on a nested page shows
the path back to the root node.

Use spawns for multi-beat chains: "if X fires, set up the follow-up beat Y so
that Y can fire next turn or in a few turns once its predicate matches."

### When a node fires (per turn)

For each node in the pool, the engine runs this sequence:

1. **Tick countdowns** — `delay`, `cooldown`, `sticky`, `alive` decrement.
2. **Remove expired** — nodes whose `alive` hit zero, or whose scope was
   violated by a transition, are dropped.
3. **Check eligibility** — `delay == 0`, not in cooldown, predicate evaluates
   true.
4. **Roll** — random number vs `triggerProb` + pool pressure.
5. **Pick at most one winner per pool** — weighted by `triggerProb` if
   multiple won.
6. **Fire** — apply effects, push the payload into the prompt, start the
   `cooldown` and `sticky` timers, drop spawns into the pool, remove the node
   if `scope == oneShot`.
7. **Pressure bookkeeping** — if no node in a pool fired, that pool's pressure
   creeps up; if any did, that pool's pressure resets.

### Common authoring patterns

**One-shot beat** (a single beat that fires once when conditions are met):
- `scope: oneShot`
- `triggerProb: 1.0`
- `predicate`: the condition (e.g. `character.alice.relationship.trust > 0.4`)

**Recurring background flavour** (fires sometimes when no specific condition):
- `scope: session`
- `triggerProb: 0.2`, `cooldown: 5`
- `predicate: true`

**Sticky directive** (a tonal note that influences several turns):
- `triggerProb: 1.0`, `cooldown: 20`, `sticky: 4`
- `narrative_payload`: *"She's still distant — answers are short, eyes
  averted."*
- `predicate`: when the tonal shift should start.

**Multi-beat chain via spawns**:
- Parent node fires once when conditions are met.
- Its `spawns` list contains the next beat with its own `delay` (so it
  can't fire on the same turn) and `predicate` (so it only fires when the
  follow-up makes sense).

**Conditional reaction** (fires only after a flag is set by an earlier beat):
- Earlier beat's `Effects → Flag set`: `met_stranger = true`.
- Reaction node's `predicate`: `character.alice.flags.met_stranger == true`.

## Predicates

A small expression language over the state namespace. Examples:

```
character.alice.emotion.joy > 0.5
character.alice.relationship.bob >= 0.3 and not global.flags.alice_left
global.phase == "scene" or global.scene.location == "tavern"
```

Operators: `and`, `or`, `not`, `==`, `!=`, `<`, `<=`, `>`, `>=`. Literals are
numbers (`0.5`), strings (`"tavern"`), and booleans (`true`, `false`).

Paths walk the state shape:

- `character.<id>.emotion.<name>` (e.g. `joy`, `sadness`, `anger`, `fear`)
- `character.<id>.physical.<name>`
- `character.<id>.relationship.<id>`
- `character.<id>.flags.<name>`
- `character.<id>.knowledge.<topic>.value` or `.confidence`
- `global.scene.location`, `global.scene.timeOfDay`,
  `global.scene.presentEntities`, `global.scene.sensoryHooks`
- `global.phase`, `global.goal`, `global.turn`
- `global.flags.<name>`

A bare field reference (no operator) is truthy when the value is non-zero,
non-empty, or `true`.

Predicates are parsed once per node and cached, so they cost nothing on
repeat evaluation.

## State shape

One `SessionState` per chat:

```
characters: { "alice": CharacterState, "bob": CharacterState }
currentGoal: "meet the stranger"
currentPhase: scene | sequel
currentScene: { location, time_of_day, presentEntities, sensoryHooks }
flags: { "alice_left": true }
eventLog: [ EventLogEntry, ... ]
turn: 14
```

Each `CharacterState` holds three tracked-value maps (emotion, physical,
relationship), one knowledge map, and one flags map. Tracked values clamp
between -1 and 1 and support a short "lockout" so the opposite axis cannot
immediately rebound after a strong swing in one direction.

## Host integration

The package provides building blocks. The host wires them. A minimal per-turn
loop looks like:

```dart
// Pre-reply.
pool.tick();
final result = engine.runTurn(pool, state);

final dynamicSection = await promptAssembler.assembleDynamicSections(
  state: state,
  pool: pool,
  firedThisTurn: result.fired,
  userInput: userInput,
  maxContextTokens: 8000,
);
// Host stitches dynamicSection into the actor's system prompt.

// Actor call happens here (outside the package).

// Post-reply.
final output = await directorRunner.run(
  state: state,
  actorLastOutput: assistantReply,
  userInput: userInput,
);
applyDirectorOutput(output, state);

// Host persists state and pool to its own store.
```

`PromptAssembler.assembleDynamicSections` returns one string with up to four
blocks:

1. **Scene**: location, time of day, present entities, sensory hooks.
2. **State**: goal, phase, and any character emotion above the prominence
   threshold (default 0.5).
3. **Lingering**: narrative payloads from previously fired nodes whose sticky
   counter is still positive.
4. **Now**: narrative payloads from nodes that fired this turn.
5. **Earlier**: relevant event-log entries, if an `Embedder` was supplied
   (cosine similarity to the user input). Falls back to recency when no
   embedder is wired.

Sections 2 through 5 share a character budget computed from
`maxContextTokens` so the injection never balloons.

## The director call

`DirectorRunner.run` builds a system prompt from a fixed preamble plus the
current `SessionState` as JSON plus the actor's last reply plus the user's
last input. It calls `LlmRunner.completeStructured` with a JSON schema for
`DirectorOutput`, parses the response, validates it (bounds on deltas,
predicate parse check on any generated nodes), and retries on failure. After
the retry budget is exhausted, it returns an empty `DirectorOutput`, which is
a no-op for the turn.

The director can:

- write `emotion_deltas`, `physical_deltas`, `relationship_deltas` per character
- set flat `flag_set` values
- append `directive_lines` (short authorial nudges, applied as sticky notes)
- append `event_log_append` entries

The director cannot:

- change `goal`, `phase`, or `scene` (only fired nodes can)
- fire nodes
- pick from a node menu (it never sees the pool)

## Observability

Each call to `FiringEngine.runTurn` emits one `TurnFiringEvent` on a
`Logger('cardwave.nodes')` info record. The event bundles every skip reason,
every roll, and every firing for the turn, so the host gets one log entry per
turn rather than one per node. A 10-node pool no longer floods the log viewer.

The host can listen via `Logger.root.onRecord` and forward `TurnFiringEvent`
to its own log surface:

```dart
Logger.root.onRecord.listen((record) {
  final object = record.object;
  if (object is TurnFiringEvent) {
    myLogger.info(formatTurnFiring(object));
  }
});
```

## What this package does not do

- No file IO. The host owns persistence and feeds `SessionState` and `NodePool`
  back in on the next chat open.
- No settings or provider plumbing. The host injects an `LlmRunner` (and
  optionally an `Embedder`).
- No UI. Everything round-trips through JSON; rendering is the host's call.
- No turn coordination. The host decides when to run the engine, when to call
  the director, and when to persist.
