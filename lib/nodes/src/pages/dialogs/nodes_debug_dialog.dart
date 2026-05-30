import 'dart:convert';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/src/services/nodes_service.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';

/// Read-only snapshot of the NODES engine state for the currently
/// open chat. Spec §10 panels surfaced here:
///   - scene, goal, phase, flags
///   - every character's emotion, physical, and relationship values
///     (with lockout countdowns)
///   - every node in the pool (with runtime countdowns, predicate
///     text, and the predicate's current evaluation against state)
///   - the tail of the event log
///   - the tail of the per-mutation state-change log
///   - the director's most recent JSON output
///   - the actor prompt assembly breakdown (per-section char counts)
///
/// Snapshot only; close and re-open to see updates.
class NodesDebugDialog extends StatelessWidget {
  const NodesDebugDialog({required this.nodesService, super.key});

  final NodesService nodesService;

  /// Tail size for the event log section.
  static const int _eventLogTail = 10;

  /// Tail size for the state-change log section.
  static const int _stateChangeTail = 20;

  @override
  Widget build(BuildContext context) {
    final state = nodesService.state;
    final pool = nodesService.pool;
    return AppDialog(
      builder: (context, isMobile) {
        if (state == null || pool == null) {
          return const Text(
            'No NODES state for this chat yet. Send a message — the '
            'engine opens lazily on the first turn.',
          );
        }
        final textTheme = Theme.of(context).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text('NODES Engine (debug)', style: textTheme.titleMedium),
            _Section(
              title: 'Scene',
              child: _SceneBlock(scene: state.currentScene),
            ),
            _Section(
              title: 'Session',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Turn: ${state.turn}'),
                  Text('Phase: ${state.currentPhase.name}'),
                  if (state.currentGoal.isNotEmpty)
                    Text('Goal: ${state.currentGoal}'),
                  if (state.flags.isNotEmpty) Text('Flags: ${state.flags}'),
                  if (state.pendingDirectives.isNotEmpty)
                    Text(
                      'Pending directives: '
                      '${state.pendingDirectives.length}',
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Characters',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in state.characters.entries)
                    _CharacterBlock(
                      characterId: entry.key,
                      character: entry.value,
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Pool (${pool.active.length})',
              child: pool.active.isEmpty
                  ? const Text('Empty.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final node in pool.active)
                          _NodeBlock(node: node, state: state),
                      ],
                    ),
            ),
            _Section(
              title:
                  'Event log '
                  '(${state.eventLog.length} total, last $_eventLogTail)',
              child: state.eventLog.isEmpty
                  ? const Text('Empty.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry
                            in _tail(state.eventLog, _eventLogTail))
                          Text(
                            'turn ${entry.turn} '
                            '(${entry.significance.toStringAsFixed(2)}): '
                            '${entry.text}',
                          ),
                      ],
                    ),
            ),
            _Section(
              title:
                  'State changes '
                  '(${nodesService.changeLog.entries.length} total, '
                  'last $_stateChangeTail)',
              child: nodesService.changeLog.entries.isEmpty
                  ? const Text('Empty.')
                  : _StateChangeList(
                      entries: nodesService.changeLog.entries,
                      tail: _stateChangeTail,
                    ),
            ),
            _Section(
              title: 'Director (last output)',
              child: _DirectorBlock(output: nodesService.lastDirectorOutput),
            ),
            _Section(
              title: 'Prompt assembly (last turn)',
              child: _PromptBreakdownBlock(
                breakdown: nodesService.lastPromptBreakdown,
              ),
            ),
          ],
        );
      },
    );
  }

  static Iterable<T> _tail<T>(List<T> list, int n) =>
      list.length <= n ? list : list.skip(list.length - n);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SceneBlock extends StatelessWidget {
  const _SceneBlock({required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (scene.location.isNotEmpty) 'Location: ${scene.location}',
      if (scene.timeOfDay.isNotEmpty) 'Time: ${scene.timeOfDay}',
      if (scene.presentEntities.isNotEmpty)
        'Present: ${scene.presentEntities.join(", ")}',
      if (scene.sensoryHooks.isNotEmpty)
        'Sensory: ${scene.sensoryHooks.join(", ")}',
    ];
    if (lines.isEmpty) return const Text('Empty.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final line in lines) Text(line)],
    );
  }
}

class _CharacterBlock extends StatelessWidget {
  const _CharacterBlock({required this.characterId, required this.character});

  final String characterId;
  final CharacterState character;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(characterId, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final entry in character.emotion.entries)
            Text(_trackedValueLine(entry.key.name, entry.value)),
          for (final entry in character.physical.entries)
            Text(_trackedValueLine(entry.key.name, entry.value)),
          for (final entry in character.relationship.entries)
            Text(_trackedValueLine(entry.key.name, entry.value)),
        ],
      ),
    );
  }

  static String _trackedValueLine(String name, TrackedValue value) {
    final lock = value.lockoutTurnsRemaining > 0
        ? '  (lock ${value.lockoutTurnsRemaining})'
        : '';
    return '  ${name.padRight(13)} ${value.value.toStringAsFixed(2)}$lock';
  }
}

class _NodeBlock extends StatelessWidget {
  const _NodeBlock({required this.node, required this.state});

  final Node node;
  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final eligible = _eligibilityFor(node, state);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${node.id}  [${node.type.name}, ${node.origin.name}]',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '  delay ${node.currentDelay}, '
            'cooldown ${node.currentCooldown}, '
            'sticky ${node.currentSticky}, '
            'alive ${node.currentAlive}',
          ),
          Text('  predicate: ${node.predicate}',
              style: TextStyle(color: muted)),
          Text(
            '  -> ${eligible.label}',
            style: TextStyle(
              color: eligible.isEligible
                  ? theme.colorScheme.primary
                  : muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  static _Eligibility _eligibilityFor(Node node, SessionState state) {
    if (node.currentDelay > 0) {
      return const _Eligibility(false, 'skipped (delay)');
    }
    if (node.currentCooldown > 0) {
      return const _Eligibility(false, 'skipped (cooldown)');
    }
    try {
      final ast = parsePredicate(node.predicate);
      final result = evaluatePredicate(ast, state);
      return _Eligibility(result, result ? 'predicate true' : 'predicate false');
    } on PredicateParseException catch (e) {
      return _Eligibility(false, 'predicate parse error: ${e.message}');
    }
  }
}

class _Eligibility {
  const _Eligibility(this.isEligible, this.label);

  final bool isEligible;
  final String label;
}

class _StateChangeList extends StatelessWidget {
  const _StateChangeList({required this.entries, required this.tail});

  final List<StateChangeRecord> entries;
  final int tail;

  @override
  Widget build(BuildContext context) {
    final shown = entries.length <= tail
        ? entries
        : entries.sublist(entries.length - tail);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final record in shown)
          Text(
            'turn ${record.turn} [${record.category.name}] ${record.description}',
            style: TextStyle(
              color: record.category == StateChangeCategory.decay
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
      ],
    );
  }
}

class _DirectorBlock extends StatelessWidget {
  const _DirectorBlock({required this.output});

  final DirectorOutput? output;

  @override
  Widget build(BuildContext context) {
    final value = output;
    if (value == null) {
      return const Text('No director output yet.');
    }
    final encoded = const JsonEncoder.withIndent('  ').convert(value.toJson());
    return Text(
      encoded,
      style: const TextStyle(fontFamily: 'monospace'),
    );
  }
}

class _PromptBreakdownBlock extends StatelessWidget {
  const _PromptBreakdownBlock({required this.breakdown});

  final PromptBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown.totalChars == 0 && breakdown.budgetChars == 0) {
      return const Text('No prompt assembled yet.');
    }
    final lines = <String>[
      'scene: ${breakdown.sceneChars}',
      'state: ${breakdown.stateChars}',
      'lingering: ${breakdown.lingeringChars}',
      'directives: ${breakdown.directivesChars}',
      'now: ${breakdown.nowChars}',
      'earlier: ${breakdown.earlierChars}',
      'total: ${breakdown.totalChars} / budget ${breakdown.budgetChars} '
          '(${_pct(breakdown.totalChars, breakdown.budgetChars)})',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final line in lines) Text(line)],
    );
  }

  static String _pct(int used, int budget) {
    if (budget == 0) return 'no budget';
    final pct = (used * 100 / budget).clamp(0, 999).toStringAsFixed(0);
    return '$pct%';
  }
}
