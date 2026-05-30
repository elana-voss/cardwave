/// Key under which authored nodes + emotion baseline + initial
/// goal / scene live in a SillyTavern v3 card's `extensions` map.
/// Single source of truth shared by the runtime (`NodesService`) and
/// the authoring UI (`EditorNodes`) so both read and write the same
/// slot.
const String nodesCardExtensionKey = 'cardwave_nodes';
