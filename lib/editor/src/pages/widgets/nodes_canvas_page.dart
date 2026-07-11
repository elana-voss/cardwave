import 'dart:async';

import 'package:cardwave/editor/src/pages/widgets/nodes_canvas_view.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';

/// Full-screen host for the visual editor. Pushed from the Nodes panel;
/// the panel stays alive underneath and owns the node list and persist
/// path — this page only forwards the canvas's edits to it.
///
/// Because this page lives on its own route, the panel's rebuilds never
/// reach the canvas. Edits made ON the canvas are already inside its
/// controller, but edits made through the node dialog (opened from a
/// box's context menu) or the add button are outside changes — so this
/// page re-renders the canvas after each of those completes, letting its
/// diff sync apply the deltas.
class NodesCanvasPage extends StatefulWidget {
  const NodesCanvasPage({
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
  final void Function(String nodeId, double x, double y) onPositionChanged;
  final void Function(String sourceId, String targetId) onLink;
  final void Function(String sourceId, String targetId) onUnlink;

  /// Opens the node-editor dialog for this id; completes when it closes.
  final Future<void> Function(String nodeId) onEditNode;

  /// Confirms and deletes the node with this id (links toward it die
  /// with it); completes when the confirm closes.
  final Future<void> Function(String nodeId) onDeleteNode;

  /// Appends a fresh node to the card.
  final VoidCallback onAddNode;

  @override
  State<NodesCanvasPage> createState() => _NodesCanvasPageState();
}

class _NodesCanvasPageState extends State<NodesCanvasPage> {
  Future<void> _editNode(String nodeId) async {
    await widget.onEditNode(nodeId);
    if (mounted) setState(() {});
  }

  Future<void> _deleteNode(String nodeId) async {
    await widget.onDeleteNode(nodeId);
    if (mounted) setState(() {});
  }

  void _addNode() {
    widget.onAddNode();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.editor.editorNodes.visualEditorTooltip),
      ),
      body: NodesCanvasView(
        nodes: widget.nodes,
        onPositionChanged: widget.onPositionChanged,
        onLink: widget.onLink,
        onUnlink: widget.onUnlink,
        onEditNode: (nodeId) => unawaited(_editNode(nodeId)),
        onDeleteNode: (nodeId) => unawaited(_deleteNode(nodeId)),
        onAddNode: (_) => _addNode(),
      ),
    );
  }
}
