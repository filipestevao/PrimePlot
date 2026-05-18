import 'package:flutter/foundation.dart';
import '../src/rust/api/data.dart';
import '../src/rust/api/project.dart';

/// A lightweight, globally accessible state manager.
class ProjectState {
  static final ProjectState instance = ProjectState._internal();
  ProjectState._internal();

  /// Holds the active DataTable. Both the Table UI and the Canvas listen to this.
  final ValueNotifier<DTODataTable?> activeTable = ValueNotifier(null);
  
  /// Controls whether the table cells are currently editable.
  final ValueNotifier<bool> isTableEditable = ValueNotifier(true);

  // Panel titles (legacy for current layout)
  final ValueNotifier<String> tableName = ValueNotifier('Table');
  final ValueNotifier<String> graphName = ValueNotifier('Graph');
  
  // Dynamic project tree state
  final ValueNotifier<ProjectNode?> projectTree = ValueNotifier(null);

  void loadInitialData() {
    activeTable.value = getInitialTableData();
    projectTree.value = getProjectTree();
  }

  void updateTable(DTODataTable newTable) {
    activeTable.value = newTable;
  }

  void toggleTableEditMode() {
    isTableEditable.value = !isTableEditable.value;
  }

  void addProjectNodeWrapper(String parentId, String name, NodeType type) {
    final newTree = addProjectNode(parentId: parentId, name: name, nodeType: type);
    projectTree.value = newTree;
  }

  void moveProjectNodeWrapper(String nodeId, String newParentId) {
    final newTree = moveProjectNode(nodeId: nodeId, newParentId: newParentId);
    projectTree.value = newTree;
  }

  void renameProjectNodeWrapper(String nodeId, String newName) {
    final newTree = renameProjectNode(nodeId: nodeId, newName: newName);
    projectTree.value = newTree;
    // Also update legacy names if editing the default items
    if (nodeId == 'table_1') tableName.value = newName;
    if (nodeId == 'graph_1') graphName.value = newName;
  }
}
