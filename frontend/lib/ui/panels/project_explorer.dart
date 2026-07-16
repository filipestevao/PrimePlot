// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../src/rust/api/project.dart';
import '../../core/theme.dart';
import '../../core/state.dart';

enum TableAction { rename, delete }

class _FlatNode {
  final ProjectNode node;
  final int indent;
  final String parentId;
  final bool isRoot;

  _FlatNode({
    required this.node,
    required this.indent,
    required this.parentId,
    this.isRoot = false,
  });
}

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({super.key});

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  String? _editingNodeId;
  final TextEditingController _editController = TextEditingController();
  final Set<String> _expandedNodes = {};

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

  List<_FlatNode> _flattenTree(ProjectNode root) {
    final List<_FlatNode> flatList = [];
    // Do not add root to flatList, so it remains hidden.
    
    // _expandedNodes stores the nodes that are COLLAPSED (hidden children)
    if (!_expandedNodes.contains(root.id)) {
      for (final child in root.children) {
        _traverseNode(child, 0, root.id, flatList); // Children of root start at indent 0
      }
    }
    return flatList;
  }

  void _traverseNode(ProjectNode node, int indent, String parentId, List<_FlatNode> flatList) {
    flatList.add(_FlatNode(node: node, indent: indent, parentId: parentId));
    
    if (!_expandedNodes.contains(node.id)) {
      for (final child in node.children) {
        _traverseNode(child, indent + 1, node.id, flatList);
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex, List<_FlatNode> flatNodes, ProjectNode rootNode) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final draggedItem = flatNodes[oldIndex];
    if (draggedItem.isRoot) return; // Cannot reorder root

    String targetParentId = '';
    
    // Fallback: the node above the drop index. 
    // If we dropped it at index 0, that's before root, invalid.
    if (newIndex == 0) return;
    
    // Identify what item is just above our drop position
    final prevNode = flatNodes[newIndex];

    if (draggedItem.node.nodeType == NodeType.dataset) {
      // Must go into a plot (chart)
      if (prevNode.node.nodeType == NodeType.plot) {
        // Drop onto a plot: place inside the plot if it's not collapsed
        if (!_expandedNodes.contains(prevNode.node.id)) {
          targetParentId = prevNode.node.id;
        } else {
          // It's collapsed, so maybe the user meant to drop it into the plot's parent? 
          // But datasets can ONLY be in plots. If plot is collapsed, we still put it in this plot.
          targetParentId = prevNode.node.id;
        }
      } else if (prevNode.node.nodeType == NodeType.dataset) {
        // Drop onto another dataset: put it in the same parent plot
        targetParentId = prevNode.parentId;
      } else {
        // Invalid (dropped onto folder or root directly)
        return;
      }
    } else if (draggedItem.node.nodeType == NodeType.plot) {
      // Must go into a folder or root
      if (prevNode.node.nodeType == NodeType.folder) {
        if (!_expandedNodes.contains(prevNode.node.id)) {
          targetParentId = prevNode.node.id;
        } else {
          targetParentId = prevNode.parentId;
        }
      } else if (prevNode.node.nodeType == NodeType.plot) {
        targetParentId = prevNode.parentId;
      } else if (prevNode.node.nodeType == NodeType.dataset) {
        final plotId = prevNode.parentId;
        final plotNode = flatNodes.firstWhere((n) => n.node.id == plotId);
        targetParentId = plotNode.parentId;
      } else {
        targetParentId = rootNode.id;
      }
    } else if (draggedItem.node.nodeType == NodeType.folder) {
      // Must go into root
      targetParentId = rootNode.id;
    }

    final draggedId = draggedItem.node.id;
    final inSameParent = draggedItem.parentId == targetParentId;

    if (inSameParent) {
      // Find the old and new index within the parent's children array
      final parentNode = _findNodeById(rootNode, targetParentId);
      if (parentNode == null) return;
      
      int fromIdx = parentNode.children.indexWhere((n) => n.id == draggedId);
      if (fromIdx == -1) return;
      
      // Calculate target index among siblings
      // This is tricky, so we rely on rust backend to handle insert.
      // For now, let's just move it to end, or just accept that dragging down moves it
      // For a more accurate reorder:
      int toIdx = 0;
      for (int i = 0; i <= newIndex; i++) {
         if (flatNodes[i].parentId == targetParentId && flatNodes[i].node.id != draggedId) {
            toIdx++;
         }
      }
      ProjectState.instance.reorderGraphChildren(targetParentId, fromIdx, toIdx);
    } else {
      // Changing parent
      ProjectState.instance.moveProjectNodeWrapper(draggedId, targetParentId);
      
      // Calculate where to place it in the new parent
      final parentNode = _findNodeById(rootNode, targetParentId);
      if (parentNode != null) {
         int toIdx = 0;
         for (int i = 0; i <= newIndex; i++) {
            if (flatNodes[i].parentId == targetParentId && flatNodes[i].node.id != draggedId) {
               toIdx++;
            }
         }
         // Move is appended to end by default in rust, so fromIdx is children.length
         ProjectState.instance.reorderGraphChildren(targetParentId, parentNode.children.length, toIdx);
      }
    }
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
        
        final flatNodes = _flattenTree(rootNode);

        return Material(
          color: PrimeTheme.panelBackground,
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: flatNodes.length,
            itemBuilder: (context, index) {
              final flatNode = flatNodes[index];
              return _dispatchFlatNode(flatNode, index);
            },
            onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, flatNodes, rootNode),
          ),
        );
      },
    );
  }

  Widget _dispatchFlatNode(_FlatNode flatNode, int index) {
    if (flatNode.isRoot) {
      return Container(
        key: ValueKey(flatNode.node.id),
        child: _buildRootNode(flatNode.node, index),
      );
    }
    switch (flatNode.node.nodeType) {
      case NodeType.plot:
        return Container(
          key: ValueKey(flatNode.node.id),
          child: _buildGraphNode(flatNode, index),
        );
      case NodeType.folder:
        return Container(
          key: ValueKey(flatNode.node.id),
          child: _buildFolderNode(flatNode, index),
        );
      case NodeType.dataset:
        return Container(
          key: ValueKey(flatNode.node.id),
          child: _buildTableRow(flatNode, index),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Root node
  // ---------------------------------------------------------------------------

  Widget _buildRootNode(ProjectNode root, int index) {
    return _styledTile(
      indent: 0,
      icon: Icons.folder,
      iconColor: const Color(0xFFFFC107), // amber
      label: root.name,
      isEditing: false,
      node: root,
      isRoot: true,
      hasChildren: root.children.isNotEmpty,
      index: index,
    );
  }

  // ---------------------------------------------------------------------------
  // Folder node
  // ---------------------------------------------------------------------------

  Widget _buildFolderNode(_FlatNode folderNode, int index) {
    return _styledTile(
      indent: folderNode.indent,
      icon: Icons.folder,
      iconColor: const Color(0xFFFFC107),
      label: folderNode.node.name,
      isEditing: _editingNodeId == folderNode.node.id,
      node: folderNode.node,
      hasChildren: folderNode.node.children.isNotEmpty,
      index: index,
    );
  }

  // ---------------------------------------------------------------------------
  // Graph node
  // ---------------------------------------------------------------------------

  Widget _buildGraphNode(_FlatNode graphNode, int index) {
    return _styledTile(
      indent: graphNode.indent,
      icon: Icons.show_chart,
      iconColor: PrimeTheme.primaryAccent,
      label: graphNode.node.name,
      isEditing: _editingNodeId == graphNode.node.id,
      node: graphNode.node,
      hasChildren: graphNode.node.children.isNotEmpty,
      index: index,
    );
  }

  // ---------------------------------------------------------------------------
  // Table row
  // ---------------------------------------------------------------------------

  Widget _buildTableRow(_FlatNode tableNode, int index) {
    final table = tableNode.node;
    final isEditing = _editingNodeId == table.id;
    final isSelected = _isSelected(table.id);
    final double leftPad = 12.0 + tableNode.indent * 16.0 + 16.0;

    return Material(
      color: isSelected
          ? PrimeTheme.primaryAccent.withValues(alpha: 0.15)
          : Colors.transparent,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => ProjectState.instance.selectProjectNode(table.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: EdgeInsets.only(left: leftPad, right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.table_chart,
                  size: 16,
                  color: isSelected ? PrimeTheme.primaryAccent : Colors.greenAccent,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: isEditing
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
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEditing) ...[
                      Builder(
                        builder: (ctx) => InkWell(
                          onTap: () => _showNodeMenu(ctx, table),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.more_vert, size: 16, color: PrimeTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ReorderableDragStartListener(
                        index: index,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.move,
                          child: Icon(Icons.drag_handle,
                              size: 20, color: PrimeTheme.textSecondary.withValues(alpha: 0.5)),
                        ),
                      ),
                    ] else ...[
                      _miniIconButton(
                        icon: Icons.check,
                        color: Colors.greenAccent,
                        onPressed: () => _finishEditing(table.id),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Popup menu actions
  // ---------------------------------------------------------------------------

  void _showNodeMenu(BuildContext context, ProjectNode node) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<TableAction>(
      context: context,
      position: position,
      color: PrimeTheme.backgroundDark,
      items: [
        const PopupMenuItem(
          value: TableAction.rename,
          child: Text('Rename', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
        ),
        const PopupMenuItem(
          value: TableAction.delete,
          child: Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      ],
    ).then((action) {
      if (action != null) {
        if (node.nodeType == NodeType.dataset) {
          _onTableAction(action, node);
        } else {
          _onGraphAction(action, node);
        }
      }
    });
  }

  void _onTableAction(TableAction action, ProjectNode node) {
    if (action == TableAction.rename) {
      _startEditing(node.id, node.name);
    } else if (action == TableAction.delete) {
      _showDeleteConfirmationDialog(node);
    }
  }

  void _onGraphAction(TableAction action, ProjectNode node) {
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
        title: const Text('Delete Node'),
        content: Text('Do you really want to delete "${node.name}"?'),
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
  // Shared expandable tile builder
  // ---------------------------------------------------------------------------

  Widget _styledTile({
    required int indent,
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isEditing,
    required ProjectNode node,
    required bool hasChildren,
    required int index,
    bool isRoot = false,
  }) {
    final double leftPad = 12.0 + indent * 16.0;
    final isExpanded = !_expandedNodes.contains(node.id);
    final isSelected = _isSelected(node.id);

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

    final expandToggle = (!isRoot && hasChildren)
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedNodes.add(node.id);
                  } else {
                    _expandedNodes.remove(node.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 16,
                  color: PrimeTheme.textSecondary,
                ),
              ),
            ),
          )
        : null;

    final trailingWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isEditing) ...[
          Builder(
            builder: (ctx) => InkWell(
              onTap: () => _showNodeMenu(ctx, node),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.more_vert, size: 16, color: PrimeTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Icon(Icons.drag_handle,
                  size: 20, color: PrimeTheme.textSecondary.withValues(alpha: 0.5)),
            ),
          ),
        ] else ...[
          _miniIconButton(
            icon: Icons.check,
            color: Colors.greenAccent,
            onPressed: () => _finishEditing(node.id),
          ),
        ],
        if (expandToggle != null) ...[
          const SizedBox(width: 4),
          expandToggle,
        ],
      ],
    );

    return Material(
      color: isSelected
          ? PrimeTheme.primaryAccent.withValues(alpha: 0.15)
          : Colors.transparent,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => ProjectState.instance.selectProjectNode(node.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: EdgeInsets.only(left: leftPad, right: 16),
            child: Row(
              children: [
                Icon(icon, size: 16, color: isSelected ? PrimeTheme.primaryAccent : iconColor),
                const SizedBox(width: 16),
                Expanded(child: titleWidget),
                if (trailingWidget != null) trailingWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

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
}
