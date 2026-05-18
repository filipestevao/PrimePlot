import 'package:flutter/material.dart';
import '../../src/rust/api/project.dart';
import '../../core/theme.dart';
import '../../core/state.dart';

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({super.key});

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  String? _editingNodeId;
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEditing(String id, String currentName) {
    setState(() {
      _editingNodeId = id;
      _editController.text = currentName;
      _editController.selection = TextSelection(baseOffset: 0, extentOffset: currentName.length);
    });
  }

  void _finishEditing(String id) {
    if (_editController.text.isNotEmpty) {
      ProjectState.instance.renameProjectNodeWrapper(id, _editController.text);
    }
    setState(() {
      _editingNodeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProjectNode?>(
      valueListenable: ProjectState.instance.projectTree,
      builder: (context, rootNode, child) {
        if (rootNode == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          color: PrimeTheme.panelBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildTreeNode(rootNode),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTreeNode(ProjectNode node) {
    final IconData iconData;
    final Color iconColor;

    switch (node.nodeType) {
      case NodeType.folder:
        iconData = Icons.folder;
        iconColor = Colors.amber;
        break;
      case NodeType.dataset:
        iconData = Icons.table_chart;
        iconColor = Colors.greenAccent;
        break;
      case NodeType.plot:
        iconData = Icons.show_chart;
        iconColor = PrimeTheme.primaryAccent;
        break;
    }

    final isEditing = _editingNodeId == node.id;
    final bool isRoot = node.id == 'root_1';

    // The inner UI for the node's title
    Widget titleWidget = Row(
      children: [
        Expanded(
          child: isEditing 
            ? SizedBox(
                height: 24,
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
                style: const TextStyle(fontSize: 13, color: PrimeTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
        ),
        if (!isEditing && !isRoot) ...[
          IconButton(
            icon: const Icon(Icons.edit, size: 14),
            color: PrimeTheme.textSecondary,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _startEditing(node.id, node.name),
          ),
        ] else if (isEditing) ...[
          IconButton(
            icon: const Icon(Icons.check, size: 14),
            color: Colors.greenAccent,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _finishEditing(node.id),
          ),
        ],
      ],
    );

    // Draggable wraps the row so we can drag it
    Widget draggableTitle = LongPressDraggable<String>(
      data: node.id,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: PrimeTheme.backgroundDark.withOpacity(0.8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(node.name, style: const TextStyle(fontSize: 13, color: PrimeTheme.textPrimary)),
            ],
          ),
        ),
      ),
      child: titleWidget,
    );

    // DragTarget allows us to drop another node onto this node
    Widget targetWidget = DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Prevent dropping onto itself or root dropping
        if (details.data == node.id || details.data == 'root_1') return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        // If node is a folder, drop into it. Otherwise, drop into its parent? 
        // We only have node_id here. For simplicity, drop into folder if it's a folder,
        // otherwise we could drop into the same parent, but let's just make folder dropping work.
        if (node.nodeType == NodeType.folder) {
          ProjectState.instance.moveProjectNodeWrapper(details.data, node.id);
        } else {
          // It would be nice to get parent_id, but the backend handles it.
          // For now, we drop onto a node, so we'll just put it in root if we can't figure it out,
          // but we can just use moveProjectNodeWrapper and let the user drop strictly on folders.
          // Let's assume dropping on a leaf does nothing or adds it to the leaf's parent.
          // Wait, we don't have leaf's parent ID easily here unless we traverse.
          // So let's only accept drops on Folders for now.
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        
        if (node.children.isEmpty && node.nodeType != NodeType.folder) {
          return Container(
            color: isHovered ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent,
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
              leading: Icon(iconData, size: 16, color: iconColor),
              title: isRoot ? titleWidget : draggableTitle,
            ),
          );
        }

        return Container(
          color: isHovered ? PrimeTheme.primaryAccent.withOpacity(0.2) : Colors.transparent,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
              childrenPadding: const EdgeInsets.only(left: 16.0),
              leading: Icon(iconData, size: 18, color: iconColor),
              title: isRoot ? titleWidget : draggableTitle,
              iconColor: PrimeTheme.textSecondary,
              collapsedIconColor: PrimeTheme.textSecondary,
              children: node.children.map((child) => _buildTreeNode(child)).toList(),
            ),
          ),
        );
      },
    );

    return targetWidget;
  }
}
