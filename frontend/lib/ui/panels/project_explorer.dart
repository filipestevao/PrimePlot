import 'package:flutter/material.dart';
import 'package:frontend/src/rust/api/project.dart';
import '../../core/theme.dart';

class ProjectExplorer extends StatefulWidget {
  const ProjectExplorer({super.key});

  @override
  State<ProjectExplorer> createState() => _ProjectExplorerState();
}

class _ProjectExplorerState extends State<ProjectExplorer> {
  ProjectNode? _rootNode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjectTree();
  }

  void _loadProjectTree() {
    try {
      // getProjectTree is a sync function as defined in Rust via #[frb(sync)]
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
      return ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
        leading: Icon(iconData, size: 16, color: iconColor),
        title: Text(
          node.name,
          style: const TextStyle(fontSize: 13, color: PrimeTheme.textPrimary),
        ),
        onTap: () {
          // Future: handle selection
        },
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
