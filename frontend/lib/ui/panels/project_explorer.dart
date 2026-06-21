// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../src/rust/api/project.dart';
import '../../core/theme.dart';
import '../../core/state.dart';


enum TableAction { rename, delete }

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({super.key});

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  String? _editingNodeId;
  final TextEditingController _editController = TextEditingController();
  final Set<String> _expandedNodes = {};
  final Set<String> _hoveredNodeIds = {};

  @override
  void initState() {
    super.initState();
    ProjectState.instance.selectedProjectNodeId.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() => setState(() {});

  @override
  void dispose() {
    ProjectState.instance.selectedProjectNodeId.removeListener(_onSelectionChanged);
    _editController.dispose();
    super.dispose();
  }

  void _startEditing(String id, String currentName) {
    setState(() {
      _editingNodeId = id;
      _editController.text = currentName;
      _editController.selection =
          TextSelection(baseOffset: 0, extentOffset: currentName.length);
    });
  }

  void _finishEditing(String id) {
    if (_editController.text.isNotEmpty) {
      ProjectState.instance.renameProjectNodeWrapper(id, _editController.text);
    }
    setState(() => _editingNodeId = null);
  }

  bool _isSelected(String id) => ProjectState.instance.selectedProjectNodeId.value == id;

  ProjectNode? _findNodeById(ProjectNode root, String id) {
    if (root.id == id) return root;
    for (final c in root.children) {
      final found = _findNodeById(c, id);
      if (found != null) return found;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Root build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProjectNode?>(
      valueListenable: ProjectState.instance.projectTree,
      builder: (context, rootNode, child) {
        if (rootNode == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // Material (not Container) so ExpansionTile's internal ListTile
        // has a proper ancestor to paint ink effects on.
        return Material(
          color: PrimeTheme.panelBackground,
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: rootNode.children.length,
            itemBuilder: (context, index) {
              final node = rootNode.children[index];
              return ReorderableDragStartListener(
                key: ValueKey(node.id),
                index: index,
                child: _dispatchNode(node, 0),
              );
            },
            proxyDecorator: (child, index, animation) => child,
            onReorder: (oldIndex, newIndex) {
              ProjectState.instance.reorderGraphChildren('root_1', oldIndex, newIndex);
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Root node
  // ---------------------------------------------------------------------------

  Widget _buildRootNode(ProjectNode root) {
    return _styledTile(
      indent: 0,
      icon: Icons.folder,
      iconColor: const Color(0xFFFFC107), // amber
      label: root.name,
      isEditing: false,
      node: root,
      isRoot: true,
      children: root.children.map((child) => _dispatchNode(child, 1)).toList(),
    );
  }

  Widget _dispatchNode(ProjectNode node, int indent) {
    switch (node.nodeType) {
      case NodeType.plot:
        return _buildGraphNode(node, indent);
      case NodeType.folder:
        return _buildFolderNode(node, indent);
      case NodeType.dataset:
        return _buildOrphanTableRow(node, indent);
    }
  }

  // ---------------------------------------------------------------------------
  // Folder node
  // ---------------------------------------------------------------------------

  Widget _buildFolderNode(ProjectNode folder, int indent) {
    final feedbackChip = _dragChip(
      icon: Icons.folder,
      iconColor: const Color(0xFFFFC107),
      label: folder.name,
    );

    return DragTarget<String>(
      key: ValueKey(folder.id),
      onWillAcceptWithDetails: (d) {
        // Folders only accept plots
        if (d.data == folder.id || d.data == 'root_1') return false;
        final root = ProjectState.instance.projectTree.value;
        if (root == null) return false;
        final dragged = _findNodeById(root, d.data);
        return dragged != null && dragged.nodeType == NodeType.plot;
      },
      onAcceptWithDetails: (d) => ProjectState.instance.moveProjectNodeWrapper(d.data, folder.id),
      builder: (ctx, candidateData, _) => Material(
        color: candidateData.isNotEmpty
            ? PrimeTheme.primaryAccent.withValues(alpha: 0.10)
            : Colors.transparent,
        child: _styledTile(
          indent: indent,
          icon: Icons.folder,
          iconColor: const Color(0xFFFFC107),
          label: folder.name,
          isEditing: _editingNodeId == folder.id,
          node: folder,
          draggableData: folder.id,
          dragFeedback: feedbackChip,
          children: folder.children.map((child) => _dispatchNode(child, indent + 1)).toList(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Graph node
  // ---------------------------------------------------------------------------

  Widget _buildGraphNode(ProjectNode graph, int indent) {
    final feedbackChip = _dragChip(
      icon: Icons.show_chart,
      iconColor: PrimeTheme.primaryAccent,
      label: graph.name,
    );

    return DragTarget<String>(
      key: ValueKey(graph.id),
      onWillAcceptWithDetails: (d) {
        // Graphs only accept datasets
        if (d.data == graph.id || d.data == 'root_1') return false;
        final root = ProjectState.instance.projectTree.value;
        if (root == null) return false;
        final dragged = _findNodeById(root, d.data);
        return dragged != null && dragged.nodeType == NodeType.dataset;
      },
      onAcceptWithDetails: (d) => ProjectState.instance.moveProjectNodeWrapper(d.data, graph.id),
      builder: (ctx, candidateData, _) => Material(
        color: candidateData.isNotEmpty
            ? PrimeTheme.primaryAccent.withValues(alpha: 0.10)
            : Colors.transparent,
        child: _styledTile(
          indent: indent,
          icon: Icons.show_chart,
          iconColor: PrimeTheme.primaryAccent,
          label: graph.name,
          isEditing: _editingNodeId == graph.id,
          node: graph,
          draggableData: graph.id,
          dragFeedback: feedbackChip,
          children: [_buildTableList(graph, indent + 1)],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table list
  // ---------------------------------------------------------------------------

  Widget _buildTableList(ProjectNode graph, int indent) {
    final tables = graph.children
        .where((n) => n.nodeType == NodeType.dataset)
        .toList();

    if (tables.isEmpty) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
          // Empty graph area only accepts datasets
          if (d.data == graph.id || d.data == 'root_1') return false;
          final root = ProjectState.instance.projectTree.value;
          if (root == null) return false;
          final dragged = _findNodeById(root, d.data);
          return dragged != null && dragged.nodeType == NodeType.dataset;
        },
        onAcceptWithDetails: (d) => ProjectState.instance.moveProjectNodeWrapper(d.data, graph.id),
        builder: (ctx, candidateData, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 24,
          padding: EdgeInsets.only(left: 12.0 + indent * 16.0 + 16.0),
          alignment: Alignment.centerLeft,
          color: candidateData.isNotEmpty
              ? PrimeTheme.primaryAccent.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Text(
            'No tables',
            style: TextStyle(
              fontSize: 10,
              color: PrimeTheme.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return Column(
      children: tables
          .map((t) => _buildTableRow(t, graph, tables, indent))
          .toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Popup menu actions
  // ---------------------------------------------------------------------------

  void _onTableAction(TableAction action, ProjectNode node) {
    if (action == TableAction.rename) {
      _startEditing(node.id, node.name);
    } else if (action == TableAction.delete) {
      _showDeleteConfirmationDialog(node);
    }
  }

  void _showDeleteConfirmationDialog(ProjectNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PrimeTheme.panelBackground,
        title: const Text('Delete Table'),
        content: Text('Do you really want to delete the table "${node.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              ProjectState.instance.deleteProjectNodeWrapper(node.id);
              Navigator.pop(ctx);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table row — LongPressDraggable + DragTarget
  // ---------------------------------------------------------------------------

  Widget _buildTableRow(
      ProjectNode table, ProjectNode parentGraph, List<ProjectNode> siblings, int indent) {
    final isEditing = _editingNodeId == table.id;

    final feedbackChip = _dragChip(
      icon: Icons.table_chart,
      iconColor: Colors.greenAccent,
      label: table.name,
    );

    return DragTarget<String>(
      key: ValueKey('drop_${table.id}'),
      onWillAcceptWithDetails: (d) {
        // Table rows accept only datasets (for reorder or insert)
        if (d.data == table.id) return false;
        final root = ProjectState.instance.projectTree.value;
        if (root == null) return false;
        final dragged = _findNodeById(root, d.data);
        return dragged != null && dragged.nodeType == NodeType.dataset;
      },
      onAcceptWithDetails: (d) {
        final draggedId = d.data;
        final targetIdx = siblings.indexWhere((n) => n.id == table.id);
        final inSameGraph = parentGraph.children.any((n) => n.id == draggedId);

        if (inSameGraph) {
          final fromIdx = siblings.indexWhere((n) => n.id == draggedId);
          if (fromIdx != -1 && targetIdx != -1) {
            ProjectState.instance
                .reorderGraphChildren(parentGraph.id, fromIdx, targetIdx);
          }
        } else {
          ProjectState.instance
              .moveProjectNodeWrapper(draggedId, parentGraph.id);
          ProjectState.instance
              .reorderGraphChildren(parentGraph.id, siblings.length, targetIdx);
        }
      },
      builder: (ctx, candidateData, _) {
        final isDropTarget = candidateData.isNotEmpty;
        return _tableRowContent(
          table,
          isEditing,
          indent,
          isDropTarget: isDropTarget,
          dragFeedback: feedbackChip,
        );
      },
    );
  }

  Widget _tableRowContent(ProjectNode table, bool isEditing, int indent,
      {required bool isDropTarget, required Widget dragFeedback}) {
    final double leftPad = 12.0 + indent * 16.0 + 16.0;
    final isSelected = _isSelected(table.id);
    return Material(
      color: isDropTarget || isSelected
          ? PrimeTheme.primaryAccent.withValues(alpha: isDropTarget ? 0.12 : 0.15)
          : Colors.transparent,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          minLeadingWidth: 16,
          contentPadding: EdgeInsets.only(left: leftPad, right: 16),
          leading: Draggable<String>(
            data: table.id,
            feedback: dragFeedback,
            dragAnchorStrategy: childDragAnchorStrategy,
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: Icon(
                Icons.table_chart,
                size: 16,
                color: isSelected ? PrimeTheme.primaryAccent : Colors.greenAccent,
              ),
            ),
            child: Icon(
              Icons.table_chart,
              size: 16,
              color: isSelected ? PrimeTheme.primaryAccent : Colors.greenAccent,
            ),
          ),
        title: isEditing
            ? SizedBox(
                height: 20,
                child: TextField(
                  controller: _editController,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 13, color: PrimeTheme.primaryAccent),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _finishEditing(table.id),
                ),
              )
            : Text(
                table.name,
                style: const TextStyle(
                    fontSize: 13, color: PrimeTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEditing) ...[
                PopupMenuButton<TableAction>(
                  icon: const Icon(Icons.more_vert, size: 16, color: PrimeTheme.textSecondary),
                  color: PrimeTheme.backgroundDark,
                  onSelected: (action) => _onTableAction(action, table),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: TableAction.rename,
                      child: Text('Rename', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
                    ),
                    const PopupMenuItem(
                      value: TableAction.delete,
                      child: Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ),
              ] else ...[
                _miniIconButton(
                  icon: Icons.check,
                  color: Colors.greenAccent,
                  onPressed: () => _finishEditing(table.id),
                ),
              ],
              const SizedBox(width: 4),
              _dragHandle(data: table.id, feedback: dragFeedback),
            ],
          ),
          onTap: () => ProjectState.instance.selectProjectNode(table.id),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Orphan dataset (direct child of root/folder, not inside any graph)
  // ---------------------------------------------------------------------------

  Widget _buildOrphanTableRow(ProjectNode table, int indent) {
    final double leftPad = 12.0 + indent * 16.0 + 16.0;
    final feedbackChip = _dragChip(
      icon: Icons.table_chart,
      iconColor: Colors.greenAccent,
      label: table.name,
    );

    final isSelected = _isSelected(table.id);

    return Material(
      key: ValueKey(table.id),
      color: isSelected ? PrimeTheme.primaryAccent.withOpacity(0.15) : Colors.transparent,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        minLeadingWidth: 16,
        contentPadding: EdgeInsets.only(left: leftPad, right: 16),
        leading: Icon(Icons.table_chart,
            size: 16, color: isSelected ? PrimeTheme.primaryAccent : Colors.greenAccent),
        title: Text(
          table.name,
          style: TextStyle(
              fontSize: 13,
              color: isSelected ? PrimeTheme.primaryAccent : PrimeTheme.textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _dragHandle(data: table.id, feedback: feedbackChip),
        onTap: () => ProjectState.instance.selectProjectNode(table.id),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared expandable tile builder
  // ---------------------------------------------------------------------------

  Widget _styledTile({
    required int indent,
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isEditing,
    required ProjectNode node,
    required List<Widget> children,
    bool isRoot = false,
    String? draggableData,
    Widget? dragFeedback,
  }) {
    final double leftPad = 12.0 + indent * 16.0;
    final isExpanded = !_expandedNodes.contains(node.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(node, isEditing, isRoot, draggableData, dragFeedback,
            icon, iconColor, leftPad, isExpanded, children.isNotEmpty),
        if (children.isNotEmpty)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(children: children)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Drag feedback chip
  // ---------------------------------------------------------------------------

  Widget _dragChip(
      {required IconData icon,
      required Color iconColor,
      required String label}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PrimeTheme.backgroundDark.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: PrimeTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mini icon button helper
  // ---------------------------------------------------------------------------

  Widget _miniIconButton({
    required IconData icon,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon,
            size: 12,
            color: color ?? PrimeTheme.textSecondary.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _dragHandle({required String data, required Widget feedback}) {
    return Draggable<String>(
      data: data,
      feedback: feedback,
      dragAnchorStrategy: childDragAnchorStrategy,
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: Icon(Icons.drag_handle,
            size: 20, color: PrimeTheme.textSecondary.withValues(alpha: 0.5)),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Icon(Icons.drag_handle,
            size: 20, color: PrimeTheme.textSecondary.withValues(alpha: 0.5)),
      ),
    );
  }

  void _onGraphAction(TableAction action, ProjectNode node) {
    if (action == TableAction.rename) {
      _startEditing(node.id, node.name);
    } else if (action == TableAction.delete) {
      _showDeleteConfirmationDialog(node);
    }
  }

  // -------------- ------------------------------------------------------------
  // Editable title widget for graph / folder nodes
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
    ProjectNode node, bool isEditing, bool isRoot,
    String? draggableData, Widget? dragFeedback,
    IconData icon, Color iconColor, double leftPad, bool isExpanded,
    bool hasChildren,
  ) {
    final isSelected = _isSelected(node.id);

    // Leading icon (draggable when applicable)
    final leadingWidget = (draggableData != null && dragFeedback != null)
        ? Draggable<String>(
            data: draggableData,
            feedback: dragFeedback,
            dragAnchorStrategy: childDragAnchorStrategy,
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            child: Icon(icon, size: 16, color: isSelected ? PrimeTheme.primaryAccent : iconColor),
          )
        : Icon(icon, size: 16, color: isSelected ? PrimeTheme.primaryAccent : iconColor);

    // Title widget
    final titleWidget = isEditing
        ? SizedBox(
            height: 20,
            child: TextField(
              controller: _editController,
              autofocus: true,
              style: const TextStyle(fontSize: 13, color: PrimeTheme.primaryAccent),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _finishEditing(node.id),
            ),
          )
        : Text(
            node.name,
            style: TextStyle(
                fontSize: 13, color: isSelected ? PrimeTheme.primaryAccent : PrimeTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          );

    // Expand toggle widget (rightmost)
    final expandToggle = (!isRoot && hasChildren)
        ? InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedNodes.add(node.id);
                } else {
                  _expandedNodes.remove(node.id);
                }
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredNodeIds.add(node.id)),
              onExit: (_) => setState(() => _hoveredNodeIds.remove(node.id)),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: _hoveredNodeIds.contains(node.id)
                      ? Border.all(color: PrimeTheme.textSecondary.withValues(alpha: 0.5))
                      : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: PrimeTheme.textSecondary,
                ),
              ),
            ),
          )
        : null;

    // Trailing controls (popup menu + drag handle + expand toggle)
    final trailingWidget = !isRoot
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEditing)
                PopupMenuButton<TableAction>(
                  icon: const Icon(Icons.more_vert, size: 16, color: PrimeTheme.textSecondary),
                  color: PrimeTheme.backgroundDark,
                  onSelected: (action) => _onGraphAction(action, node),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: TableAction.rename,
                      child: Text('Rename', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
                    ),
                    const PopupMenuItem(
                      value: TableAction.delete,
                      child: Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                )
              else
                _miniIconButton(
                  icon: Icons.check,
                  color: Colors.greenAccent,
                  onPressed: () => _finishEditing(node.id),
                ),
              if (draggableData != null && dragFeedback != null) ...[
                const SizedBox(width: 4),
                _dragHandle(data: draggableData, feedback: dragFeedback),
              ],
              if (expandToggle != null) ...[
                const SizedBox(width: 4),
                expandToggle,
              ],
            ],
          )
        : null;

    // Single ListTile matching table row visual style, spans full width
    return Material(
      color: isSelected
          ? PrimeTheme.primaryAccent.withValues(alpha: 0.15)
          : Colors.transparent,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          minLeadingWidth: 16,
          contentPadding: EdgeInsets.only(left: leftPad, right: 16),
          leading: leadingWidget,
          title: titleWidget,
          trailing: trailingWidget,
          onTap: () => ProjectState.instance.selectProjectNode(node.id),
        ),
      ),
    );
  }
}
