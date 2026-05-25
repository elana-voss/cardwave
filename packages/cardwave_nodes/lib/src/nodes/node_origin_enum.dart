/// Where a node came from. Same schema in both cases; only the source
/// differs. Spawns inherit origin from their parent.
enum NodeOriginEnum {
  authored,
  generated,
}
