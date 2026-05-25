/// Lifetime category for a node, independent of its `alive` countdown.
///   - phase: removed at next phase transition
///   - scene: removed at next scene transition
///   - session: persists for the whole session (unless killed by alive)
///   - oneShot: removed immediately after firing once
enum NodeScopeEnum {
  phase,
  scene,
  session,
  oneShot,
}
