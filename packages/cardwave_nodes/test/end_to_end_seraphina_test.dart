import 'dart:math';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample `cardwave_nodes` extension for the canonical Seraphina card.
/// Mirrors what would live under `extensions.cardwave_nodes` in a
/// SillyTavern v3 card file.
final Map<String, dynamic> _seraphinaExtensionJson = <String, dynamic>{
  'authored_nodes': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'raise_eyebrow',
      'origin': 'authored',
      'type': 'characterBehavior',
      'trigger_prob': 0.5,
      'delay': 0,
      'cooldown': 3,
      'sticky': 0,
      'alive': -1,
      'scope': 'session',
      'predicate': 'character.seraphina.emotion.trust < 0.5',
      'narrative_payload': 'Seraphina arches an eyebrow.',
    },
    <String, dynamic>{
      'id': 'wind_rises',
      'origin': 'authored',
      'type': 'environmental',
      'trigger_prob': 0.3,
      'delay': 0,
      'cooldown': 5,
      'sticky': 0,
      'alive': -1,
      'scope': 'session',
      'predicate': 'global.scene.timeOfDay == "evening"',
      'narrative_payload': 'A breeze stirs the curtain.',
    },
    <String, dynamic>{
      'id': 'she_pauses',
      'origin': 'authored',
      'type': 'pacing',
      'trigger_prob': 0.4,
      'delay': 0,
      'cooldown': 4,
      'sticky': 1,
      'alive': -1,
      'scope': 'session',
      'predicate': 'true',
      'narrative_payload': 'She pauses, considering.',
    },
  ],
  'emotion_baseline': <String, dynamic>{
    'trust': 0.3,
    'anger': 0.1,
  },
  'initial_goal': 'size up the stranger',
  'initial_scene': <String, dynamic>{
    'location': 'tavern',
    'time_of_day': 'evening',
    'present_entities': <dynamic>[],
    'sensory_hooks': <dynamic>[],
  },
};

void main() {
  test('full session: load → seed → tick → fire → assemble → apply', () async {
    // 1. Load the card's NODES extension.
    final loaded = loadCardNodesExtension(_seraphinaExtensionJson);
    expect(loaded.errors, isEmpty,
        reason: 'Seraphina extension should be well-formed');
    expect(loaded.extension.authoredNodes, hasLength(3));
    expect(loaded.extension.initialGoal, 'size up the stranger');
    expect(loaded.extension.initialScene?.location, 'tavern');

    // 2. Bootstrap a session state from the extension.
    final state = SessionState();
    state.characters['seraphina'] = CharacterState();
    loaded.extension.emotionBaseline.forEach((emotion, value) {
      state.characters['seraphina']!.emotion[emotion]!.value = value;
    });
    state.currentGoal = loaded.extension.initialGoal;
    final initial = loaded.extension.initialScene;
    if (initial != null) state.currentScene = initial;

    expect(state.characters['seraphina']!.emotion[EmotionEnum.trust]!.value,
        0.3);

    // 3. Seed the node pool with authored nodes.
    final pool = NodePool();
    for (final node in loaded.extension.authoredNodes) {
      pool.add(node);
    }

    // 4. Build the engines.
    final firingEngine = FiringEngine(random: Random(7));
    final assembler = PromptAssembler();

    // 5. Run a handful of turns.
    final firedIds = <String>[];
    String? lastPrompt;
    for (var turn = 1; turn <= 6; turn++) {
      state.turn = turn;
      pool.tick();
      final firing = firingEngine.runTurn(pool, state);
      firedIds.addAll(firing.fired.map((n) => n.id));

      lastPrompt = await assembler.assemble(
        cardDefinition: '## Seraphina\nA stoic gunslinger.',
        state: state,
        pool: pool,
        firedThisTurn: firing.fired,
        userInput: 'You alright, Seraphina?',
        maxContextTokens: 8000,
      );

      // Mock director: small per-turn trust nudge + an event-log line.
      final directorOutput = DirectorOutput(
        emotionDeltas: {
          'seraphina': {EmotionEnum.trust: 0.03},
        },
        eventLogAppend: [
          EventLogAppend(
            text: 'turn $turn — small exchange',
            significance: 0.3,
          ),
        ],
      );
      applyDirectorOutput(directorOutput, state, pool: pool);
    }

    // Section assertions — the prompt should always carry the basics.
    expect(lastPrompt, contains('## Scene'));
    expect(lastPrompt, contains('tavern'));
    expect(lastPrompt, contains('Seraphina'));
    expect(lastPrompt, contains('Goal: size up the stranger'));
    expect(lastPrompt, contains('User: You alright, Seraphina?'));

    // State assertions — trust climbed past the baseline through the
    // director nudges; event log captured every turn.
    final trustAfter =
        state.characters['seraphina']!.emotion[EmotionEnum.trust]!.value;
    expect(trustAfter, greaterThan(0.3),
        reason: 'six director nudges of +0.03 should raise trust above '
            'the 0.3 baseline (resistance damps but does not zero them)');
    expect(state.eventLog, hasLength(6));
    expect(state.eventLog.first.turn, 1);
    expect(state.eventLog.last.turn, 6);

    // At least one authored node must have fired across 6 turns at the
    // given trigger probabilities + seed; this guards against the whole
    // firing pipeline silently doing nothing.
    expect(firedIds, isNotEmpty);
  });

  test('director can add a generated node that the pool fires later', () async {
    final loaded = loadCardNodesExtension(<String, dynamic>{});
    final state = SessionState();
    state.characters['alice'] = CharacterState();
    final pool = NodePool();
    final firingEngine = FiringEngine(random: Random(3));

    // Director generates a one-shot environmental node that fires on
    // every turn until it gets picked.
    final generated = Node(
      id: 'doorbell',
      origin: NodeOriginEnum.generated,
      type: NodeTypeEnum.environmental,
      triggerProb: 1.0,
      delay: 0,
      cooldown: 0,
      sticky: 0,
      alive: -1,
      scope: NodeScopeEnum.oneShot,
      predicate: 'true',
      narrativePayload: 'A doorbell rings.',
    );
    applyDirectorOutput(
      DirectorOutput(generatedNodes: [generated]),
      state,
      pool: pool,
    );
    expect(pool.active, hasLength(1));
    expect(pool.active.first.id, 'doorbell');

    // Now run a turn — it should fire and then be removed (one_shot).
    state.turn = 1;
    pool.tick();
    final firing = firingEngine.runTurn(pool, state);
    expect(firing.fired.map((n) => n.id), contains('doorbell'));
    expect(pool.active, isEmpty);

    // Sanity: loaded.errors empty even on an empty extension.
    expect(loaded.errors, isEmpty);
  });

  test('director emotion delta past lockout threshold locks the Plutchik opposite',
      () {
    final state = SessionState();
    state.characters['alice'] = CharacterState();
    // +0.5 to joy: magnitude exceeds lockoutThreshold (0.4) — the applier
    // must lock sadness (joy's Plutchik opposite) for lockoutDurationTurns.
    applyDirectorOutput(
      DirectorOutput(
        emotionDeltas: {
          'alice': {EmotionEnum.joy: 0.5},
        },
      ),
      state,
    );
    final sadness =
        state.characters['alice']!.emotion[EmotionEnum.sadness]!;
    expect(sadness.lockoutTurnsRemaining, 3,
        reason: 'lockout on sadness should be set to lockoutDurationTurns');
    // Sadness itself wasn't mutated (only the lockout counter).
    expect(sadness.value, 0.0);
    // Joy itself moved (resistance damping at value=0 → full delta).
    expect(state.characters['alice']!.emotion[EmotionEnum.joy]!.value, 0.5);
  });

  test('director emotion delta and event-log append survive a round-trip',
      () {
    final state = SessionState();
    state.characters['alice'] = CharacterState();
    state.turn = 4;
    applyDirectorOutput(
      DirectorOutput(
        emotionDeltas: {
          'alice': {EmotionEnum.anger: 0.4},
        },
        flagSet: {'hasArgued': true},
        eventLogAppend: [
          const EventLogAppend(
            text: 'they argued at the gate',
            significance: 0.7,
          ),
        ],
      ),
      state,
    );
    expect(state.characters['alice']!.emotion[EmotionEnum.anger]!.value, 0.4);
    expect(state.flags['hasArgued'], true);
    expect(state.eventLog, hasLength(1));
    expect(state.eventLog.first.turn, 4); // engine stamps current turn
  });
}
