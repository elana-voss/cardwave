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
