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
  ProjectNode? _rootNode;
  bool _isLoading = true;

  String? _editingNodeId;
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjectTree();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _loadProjectTree() {
    try {
      final node = getProjectTree();
      setState(() {
        _rootNode = node;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading project tree: $e');
    }
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
      if (id == 'table_1') {
        ProjectState.instance.tableName.value = _editController.text;
      } else if (id == 'graph_1') {
        ProjectState.instance.graphName.value = _editController.text;
      }
    }
    setState(() {
      _editingNodeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rootNode == null) {
      return const Center(child: Text('Failed to load project', style: TextStyle(color: PrimeTheme.textSecondary)));
    }

    return Container(
      color: PrimeTheme.panelBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              'PROJECT EXPLORER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: PrimeTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildTreeNode(_rootNode!),
              ],
            ),
          ),
        ],
      ),
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

    if (node.children.isEmpty) {
      // Leaf nodes (Dataset or Plot)
      return ValueListenableBuilder<String>(
        valueListenable: node.id == 'table_1' 
            ? ProjectState.instance.tableName 
            : (node.id == 'graph_1' ? ProjectState.instance.graphName : ValueNotifier(node.name)),
        builder: (context, currentName, child) {
          
          final isEditing = _editingNodeId == node.id;

          return ValueListenableBuilder<bool>(
            valueListenable: node.id == 'table_1' 
              ? ProjectState.instance.isTableVisible 
              : ProjectState.instance.isGraphVisible,
            builder: (context, isVisible, child) {
              return Container(
                padding: const EdgeInsets.only(left: 32.0, right: 8.0, top: 4.0, bottom: 4.0),
                child: Row(
                  children: [
                    Icon(iconData, size: 16, color: iconColor),
                    const SizedBox(width: 8),
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
                            currentName,
                            style: TextStyle(
                              fontSize: 13, 
                              color: isVisible ? PrimeTheme.textPrimary : PrimeTheme.textSecondary,
                              decoration: isVisible ? TextDecoration.none : TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                    if (!isEditing) ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 14),
                        color: PrimeTheme.textSecondary,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _startEditing(node.id, currentName),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, size: 14),
                        color: PrimeTheme.textSecondary,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (node.id == 'table_1') {
                            ProjectState.instance.isTableVisible.value = !isVisible;
                          } else if (node.id == 'graph_1') {
                            ProjectState.instance.isGraphVisible.value = !isVisible;
                          }
                        },
                      ),
                    ] else ...[
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
                ),
              );
            }
          );
        }
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
        childrenPadding: const EdgeInsets.only(left: 16.0),
        leading: Icon(iconData, size: 18, color: iconColor),
        title: Text(
          node.name,
          style: const TextStyle(fontSize: 13, color: PrimeTheme.textPrimary, fontWeight: FontWeight.w500),
        ),
        iconColor: PrimeTheme.textSecondary,
        collapsedIconColor: PrimeTheme.textSecondary,
        children: node.children.map((child) => _buildTreeNode(child)).toList(),
      ),
    );
  }
}
