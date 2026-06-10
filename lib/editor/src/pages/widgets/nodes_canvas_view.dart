import 'dart:async';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:fl_nodes/fl_nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';

/// Canvas view of a card's authored nodes, built on fl_nodes. Each node
/// is a box; dragging a wire from a box's output port to another box's
/// input port means "the first node spawns the second when it fires".
///
/// The card's flat node list is the single source of truth. This view
/// builds the diagram from it and translates the user's canvas edits
/// (wire drawn, wire removed, box moved) back into spawn-id and position
/// changes through the panel's callbacks. The package's own project
/// save/load is not used.
///
/// fl_nodes generates its own node ids, so this widget keeps a two-way
/// map between the card's node ids and the package's.
class NodesCanvasView extends StatefulWidget {
  const NodesCanvasView({
    required this.nodes,
    required this.onPositionChanged,
    required this.onLink,
    required this.onUnlink,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onAddNode,
    super.key,
  });

  final List<Node> nodes;

  /// A box was dragged: persist the node's new canvas position.
  final void Function(String nodeId, double x, double y) onPositionChanged;

  /// A wire was drawn: [sourceId] should now spawn [targetId].
  final void Function(String sourceId, String targetId) onLink;

  /// A wire was removed: [sourceId] should stop spawning [targetId].
  final void Function(String sourceId, String targetId) onUnlink;

  /// The "Edit node" context-menu entry was chosen: open the node's
  /// editor in place. Right-click on desktop, long-press on touch.
  final ValueChanged<String> onEditNode;

  /// The "Delete node" context-menu entry was chosen: confirm and remove
  /// the node from the card.
  final ValueChanged<String> onDeleteNode;

  /// The add-node button: create a fresh node at [position].
  final ValueChanged<Offset> onAddNode;

  @override
  State<NodesCanvasView> createState() => _NodesCanvasViewState();
}

class _NodesCanvasViewState extends State<NodesCanvasView> {
  /// The single output port every node carries (a node spawns others).
  static const String _outPort = 'out';

  /// The single input port every node carries (a node is spawned).
  static const String _inPort = 'in';

  /// Where a brand-new node lands before the author drags it.
  static const Offset _newNodeSpot = Offset(160, 160);

  // Snap-to-grid defaults ON (64px) in the package, which would round
  // every saved node position on load and drift the author's placement.
  // Turn it off so what they place is what gets saved.
  final FlNodeEditorController _controller = FlNodeEditorController(
    config: const FlNodeEditorConfig(enableSnapToGrid: false),
  );

  /// card node id -> fl_nodes node id, and the reverse. Rebuilt whenever
  /// the diagram is rebuilt from the card.
  final Map<String, String> _flIdByCardId = {};
  final Map<String, String> _cardIdByFlId = {};

  // The package's event base type and bus are not exported, only the
  // concrete event classes; the stream element is typed as Object here
  // and matched by concrete pattern below.
  StreamSubscription<Object>? _events;

  /// True while this widget is programmatically syncing the diagram, so
  /// the package's add-link / remove-link events fired during the sync
  /// are not mistaken for user edits and re-persisted.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    for (final type in NodeTypeEnum.values) {
      _controller.registerNodePrototype(_prototypeFor(type));
    }
    _events = _controller.eventBus.events.listen(_onCanvasEvent);
    _syncDiagram();
  }

  @override
  void didUpdateWidget(NodesCanvasView old) {
    super.didUpdateWidget(old);
    // Never mutate the controller mid-build: didUpdateWidget runs during
    // the parent's rebuild, and the package's render layer mounts its
    // children from the controller in the same pass — adding a node here
    // desyncs its child count and throws. Sync once the frame is done,
    // which is also when the package's own menus mutate the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDiagram();
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    // Positions dragged since the last flush would otherwise be lost
    // when the author leaves the view.
    _flushDraggedPositions();
    _controller.dispose();
    super.dispose();
  }

  /// Boxes the author has dragged since the last flush. The package only
  /// emits per-update drag events (its drag-END event is defined but
  /// never fired in 0.5.0+1), so positions are persisted in batches:
  /// before each sync and when the view closes.
  final Set<String> _draggedFlIds = {};

  void _flushDraggedPositions() {
    for (final flId in _draggedFlIds) {
      final cardId = _cardIdByFlId[flId];
      final box = _controller.nodes[flId];
      if (cardId != null && box != null) {
        widget.onPositionChanged(cardId, box.offset.dx, box.offset.dy);
      }
    }
    _draggedFlIds.clear();
  }

  /// Brings the controller in line with the card's node list using the
  /// package's individual add/remove calls — the controller is long-lived
  /// state, never torn down. A no-op when nothing changed, which is the
  /// common case on panel rebuilds: edits the author makes ON the canvas
  /// (drag, wire) are already in the controller when their events fire,
  /// so only outside edits (the node dialog, the raw JSON editor) produce
  /// deltas here.
  void _syncDiagram() {
    _syncing = true;

    // Persist any dragged positions first: the flush rewrites the card's
    // nodes in place, so the keep-check below compares the controller
    // against fresh stored positions instead of resetting dragged boxes.
    _flushDraggedPositions();

    final cardNodesById = {for (final node in widget.nodes) node.id: node};

    // Boxes to drop: the node was deleted, its type changed (the type is
    // the box's registered prototype, so a type change is remove+re-add),
    // or its stored position changed from outside (raw JSON editor).
    // Dropped entries fall through to the add pass below.
    for (final entry in _flIdByCardId.entries.toList()) {
      final node = cardNodesById[entry.key];
      final box = _controller.nodes[entry.value];
      final keep = node != null &&
          box != null &&
          box.prototype.idName == node.type.name &&
          box.offset == Offset(node.visualEditor.x, node.visualEditor.y);
      if (keep) continue;
      if (box != null) _controller.removeNodeById(entry.value);
      _flIdByCardId.remove(entry.key);
      _cardIdByFlId.remove(entry.value);
    }

    for (final node in widget.nodes) {
      if (_flIdByCardId.containsKey(node.id)) continue;
      final instance = _controller.addNode(
        node.type.name,
        offset: Offset(node.visualEditor.x, node.visualEditor.y),
      );
      _flIdByCardId[node.id] = instance.id;
      _cardIdByFlId[instance.id] = node.id;
    }

    // Wires: diff what the card wants against what the controller has.
    // A dangling spawn id (target deleted) is skipped; the loader flags
    // it on save.
    final wanted = <(String, String)>{};
    for (final node in widget.nodes) {
      final sourceFlId = _flIdByCardId[node.id]!;
      for (final spawnId in node.spawnIds) {
        final targetFlId = _flIdByCardId[spawnId];
        if (targetFlId != null) wanted.add((sourceFlId, targetFlId));
      }
    }
    for (final link in _controller.links.values.toList()) {
      if (!wanted.remove((link.fromTo.from, link.fromTo.fromPort))) {
        _controller.removeLinkById(link.id);
      }
    }
    for (final (sourceFlId, targetFlId) in wanted) {
      _controller.addLink(sourceFlId, _outPort, targetFlId, _inPort);
    }

    _syncing = false;
  }

  // ⚠️ fl_nodes 0.5.0+1 field-name trap: in a link's `fromTo` record,
  // `from` is the source NODE id but `to` is the source PORT name, and
  // `fromPort` is the target NODE id (`toPort` the target port). The
  // package's own addLinkFromExisting confirms this layout. Re-check on
  // any package upgrade — newer versions restructure the link record.
  void _onCanvasEvent(Object event) {
    if (_syncing) return;
    switch (event) {
      case FlAddLinkEvent():
        final sourceId = _cardIdByFlId[event.link.fromTo.from];
        final targetId = _cardIdByFlId[event.link.fromTo.fromPort];
        if (sourceId != null && targetId != null) {
          widget.onLink(sourceId, targetId);
        }
      case FlRemoveLinkEvent():
        final sourceId = _cardIdByFlId[event.link.fromTo.from];
        final targetId = _cardIdByFlId[event.link.fromTo.fromPort];
        if (sourceId != null && targetId != null) {
          widget.onUnlink(sourceId, targetId);
        }
      case FlDragSelectionEvent():
        _draggedFlIds.addAll(event.nodeIds);
    }
  }

  /// One prototype per node type. Every node carries one output port
  /// (what it spawns) and one input port (being spawned), both the same
  /// data type so an output connects to an input. The execution callback
  /// is unused — this graph is authored, not run by the package.
  FlNodePrototype _prototypeFor(NodeTypeEnum type) => FlNodePrototype(
        idName: type.name,
        displayName: (_) => type.name,
        description: (_) => '',
        ports: [
          FlDataInputPortPrototype<Object>(
            idName: _inPort,
            displayName: (_) => 'spawned by',
          ),
          FlDataOutputPortPrototype<Object>(
            idName: _outPort,
            displayName: (_) => 'spawns',
            styleBuilder: flDefaultPortStyleBuilder,
          ),
        ],
        onExecute: (_, __, ___, ____, _____) async {},
      );

  /// Mirrors the package's default header (collapse icon + title) but
  /// titles the box with the card node's name instead of the prototype's
  /// type name, which is all the default can show.
  Widget _buildNodeHeader(
    BuildContext context,
    FlNodeDataModel box,
    FlNodeStyle style,
    VoidCallback onToggleCollapse,
  ) {
    final cardId = _cardIdByFlId[box.id];
    Node? cardNode;
    for (final node in widget.nodes) {
      if (node.id == cardId) {
        cardNode = node;
        break;
      }
    }
    return Container(
      padding: box.builtHeaderStyle.padding,
      decoration: box.builtHeaderStyle.decoration,
      child: Row(
        children: [
          InkWell(
            onTap: onToggleCollapse,
            child: Icon(
              box.builtHeaderStyle.icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              cardNode?.displayLabel ?? box.prototype.displayName(context),
              style: box.builtHeaderStyle.textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlNodeEditorWidget(
          controller: _controller,
          overlay: () => const [],
          headerBuilder: _buildNodeHeader,
          contextMenuBuilder: (context, node) {
            final cardId = _cardIdByFlId[node.id];
            return [
              MenuItem(
                label: 'Edit node',
                icon: Icons.edit,
                onSelected: () {
                  if (cardId != null) widget.onEditNode(cardId);
                },
              ),
              MenuItem(
                label: 'Delete node',
                icon: Icons.delete_outline,
                onSelected: () {
                  if (cardId != null) widget.onDeleteNode(cardId);
                },
              ),
            ];
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => widget.onAddNode(_newNodeSpot),
            tooltip: 'Add node',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
