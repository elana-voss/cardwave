/// Pool grouping for nodes. Each type has its own pool with independent
/// pressure tracking and firing rules.
enum NodeTypeEnum {
  characterBehavior,
  environmental,
  event,
  pacing,
}
