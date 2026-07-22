// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../src/rust/api/data.dart';
import '../src/rust/api/project.dart';
import '../src/rust/api/properties.dart';

/// A lightweight, globally accessible state manager.
class ProjectState {
  static final ProjectState instance = ProjectState._internal();
  ProjectState._internal();

  /// Holds the active DataTable. Both the Table UI and the Canvas listen to this.
  final ValueNotifier<DTODataTable?> activeTable = ValueNotifier(null);

  /// Holds list of tables for currently selected graph. Canvas will render these
  /// when non-empty. Kept separate to preserve legacy single-table flows.
  final ValueNotifier<List<DTODataTable>> activeTables = ValueNotifier([]);

  /// Display name shown in the Table panel header (reacts to file drops & resets).
  final ValueNotifier<String> tableDisplayName = ValueNotifier('Table');

  /// Controls whether the table cells are currently editable.
  final ValueNotifier<bool> isTableEditable = ValueNotifier(true);

  // Panel titles (legacy for current layout)
  final ValueNotifier<String> tableName = ValueNotifier('Table');
  final ValueNotifier<String> graphName = ValueNotifier('Graph');

  // Dynamic project tree state
  final ValueNotifier<ProjectNode?> projectTree = ValueNotifier(null);
  final ValueNotifier<String?> selectedProjectNodeId = ValueNotifier(null);

  // Active Properties State
  final ValueNotifier<FolderProperties?> activeFolderProps = ValueNotifier(
    null,
  );
  final ValueNotifier<GraphProperties?> activeGraphProps = ValueNotifier(null);
  final ValueNotifier<TableProperties?> activeTableProps = ValueNotifier(null);
  final ValueNotifier<FunctionProperties?> activeFunctionProps = ValueNotifier(
    null,
  );
  final ValueNotifier<ShapeProperties?> activeShapeProps = ValueNotifier(null);

  void updateFolderProperties(String nodeId, FolderProperties newProps) {
    setFolderProperties(nodeId: nodeId, props: newProps);
    if (selectedProjectNodeId.value == nodeId) {
      activeFolderProps.value = newProps;
    }
  }

  void updateGraphProperties(String nodeId, GraphProperties newProps) {
    setGraphProperties(nodeId: nodeId, props: newProps);
    // If it's the active plot, update the notifier
    final activePlotId = _getActivePlotId();
    if (activePlotId == nodeId) {
      activeGraphProps.value = newProps;
    }
  }

  void updateTableProperties(String nodeId, TableProperties newProps) {
    setTableProperties(nodeId: nodeId, props: newProps);
    if (selectedProjectNodeId.value == nodeId) {
      activeTableProps.value = newProps;
    }
  }

  void updateFunctionProperties(String nodeId, FunctionProperties newProps) {
    setFunctionProperties(nodeId: nodeId, props: newProps);
    if (selectedProjectNodeId.value == nodeId) {
      activeFunctionProps.value = newProps;
    }
  }

  void updateShapeProperties(String nodeId, ShapeProperties newProps) {
    setShapeProperties(nodeId: nodeId, props: newProps);
    if (selectedProjectNodeId.value == nodeId) {
      activeShapeProps.value = newProps;
    }
  }

  String? _getActivePlotId() {
    final root = projectTree.value;
    final selectedId = selectedProjectNodeId.value;
    if (root == null || selectedId == null) return null;

    final node = findNodeById(root, selectedId);
    if (node == null) return null;

    if (node.nodeType == NodeType.plot) return node.id;
    if (node.nodeType == NodeType.dataset) {
      final parent = _findParentById(root, selectedId);
      if (parent != null && parent.nodeType == NodeType.plot) {
        return parent.id;
      }
    }
    return null;
  }

  ProjectNode? _findParentById(ProjectNode root, String targetId) {
    for (final c in root.children) {
      if (c.id == targetId) return root;
      final found = _findParentById(c, targetId);
      if (found != null) return found;
    }
    return null;
  }

  void loadInitialData() {
    // Start with an empty table – Rust is the single source of truth.
    activeTable.value = getEmptyTableData();
    projectTree.value = getProjectTree();
  }

  /// Parses a raw clipboard string via Rust and updates all dependent state.
  /// [displayName] is used when the data comes from a dropped file.
  void pasteTable(String rawText, {String? displayName}) {
    final parsed = parseClipboardTable(raw: rawText);
    activeTable.value = parsed;
    tableDisplayName.value = displayName ?? 'Table';
    if (displayName != null) {
      renameProjectNodeWrapper('table_1', displayName);
    }
  }

  /// Creates a new blank 10-row × 2-column table in the active graph.
  void newTable() {
    final parentId = getValidParentGraphId();
    if (parentId == null) return;

    final active = activeTable.value;
    if (active != null && active.columns.every((c) => c.data.isEmpty)) {
      final newColumns = active.columns
          .map(
            (col) => DTODataColumn(
              name: col.name,
              role: col.role,
              data: Float64List.fromList(List.generate(10, (_) => double.nan)),
            ),
          )
          .toList();
      saveTable(tableId: active.id, columns: newColumns);
      final updated = getTable(tableId: active.id);
      activeTable.value = updated;
      tableDisplayName.value = updated.name;
      return;
    }

    final newTree = addEmptyTable(
      parentId: parentId,
      name: 'Table',
      rowCount: BigInt.from(10),
      colCount: BigInt.from(2),
    );
    projectTree.value = newTree;
    final root = projectTree.value;
    final parent = findNodeById(root, parentId);
    if (parent != null && parent.children.isNotEmpty) {
      final newNode = parent.children.last;
      selectProjectNode(newNode.id);
    }
  }

  /// Clears all data rows, keeping the column schema, resetting to an empty table.
  void clearTableData() {
    final active = activeTable.value;
    if (active == null) return;
    final newColumns = active.columns
        .map(
          (col) => DTODataColumn(
            name: col.name,
            role: col.role,
            data: Float64List(0),
          ),
        )
        .toList();
    saveTable(tableId: active.id, columns: newColumns);
    final updated = getTable(tableId: active.id);
    activeTable.value = updated;
    tableDisplayName.value = updated.name;
  }

  void updateTable(DTODataTable newTable) {
    activeTable.value = newTable;
    final tables = activeTables.value;
    if (tables.isNotEmpty) {
      final idx = tables.indexWhere((t) => t.id == newTable.id);
      if (idx != -1) {
        final newList = List<DTODataTable>.from(tables);
        newList[idx] = newTable;
        activeTables.value = newList;
      }
    } else {
      activeTables.value = [newTable];
    }
  }

  void toggleTableEditMode() {
    isTableEditable.value = !isTableEditable.value;
  }

  void addProjectNodeWrapper(String parentId, String name, NodeType type) {
    final newTree = addProjectNode(
      parentId: parentId,
      name: name,
      nodeType: type,
    );
    projectTree.value = newTree;
  }

  /// Adds a project node and returns its generated ID.
  String addProjectNodeAndReturnId(
    String parentId,
    String name,
    NodeType type,
  ) {
    final newTree = addProjectNode(
      parentId: parentId,
      name: name,
      nodeType: type,
    );
    projectTree.value = newTree;
    // New node is the last child of parent with the matching type
    final parent = findNodeById(newTree, parentId);
    if (parent != null) {
      for (int i = parent.children.length - 1; i >= 0; i--) {
        if (parent.children[i].nodeType == type) return parent.children[i].id;
      }
    }
    return '';
  }

  void moveProjectNodeWrapper(String nodeId, String newParentId) {
    final newTree = moveProjectNode(nodeId: nodeId, newParentId: newParentId);
    projectTree.value = newTree;
  }

  void selectProjectNode(String nodeId) {
    selectedProjectNodeId.value = nodeId;

    // Attempt to resolve node type from current project tree and fetch tables
    final root = projectTree.value;
    ProjectNode? node = findNodeById(root, nodeId);
    if (node != null) {
      String? plotId;
      if (node.nodeType == NodeType.plot) {
        plotId = node.id;
      } else if (node.nodeType == NodeType.dataset ||
          node.nodeType == NodeType.function ||
          node.nodeType == NodeType.shape) {
        if (root != null) {
          final parent = _findParentById(root, node.id);
          if (parent != null && parent.nodeType == NodeType.plot) {
            plotId = parent.id;
          }
        }
      }

      // Refresh active properties based on node type
      if (node.nodeType == NodeType.folder) {
        activeFolderProps.value = getFolderProperties(nodeId: nodeId);
      } else if (node.nodeType == NodeType.plot) {
        activeGraphProps.value = getGraphProperties(nodeId: nodeId);
      } else if (node.nodeType == NodeType.dataset) {
        activeTableProps.value = getTableProperties(nodeId: nodeId);
      } else if (node.nodeType == NodeType.function) {
        activeFunctionProps.value = getFunctionProperties(nodeId: nodeId);
      } else if (node.nodeType == NodeType.shape) {
        activeShapeProps.value = getShapeProperties(nodeId: nodeId);
      }

      // Ensure graph properties are also loaded if a child of a graph is selected
      if (plotId != null && node.nodeType != NodeType.plot) {
        activeGraphProps.value = getGraphProperties(nodeId: plotId);
      }

      if (node.nodeType == NodeType.plot) {
        // Fetch all tables for this graph from Rust and update state
        fetchTablesForGraph(nodeId);
        graphName.value = node.name;
      } else if (node.nodeType == NodeType.dataset) {
        // Single dataset selected — fetch that table and set activeTable
        try {
          final table = getTable(tableId: nodeId);
          activeTable.value = table;
          // Clear multi-table view so canvas shows single table
          activeTables.value = [];
        } catch (e) {
          // ignore and keep existing state
        }
      }
    }
  }

  ProjectNode? findNodeById(ProjectNode? node, String id) {
    if (node == null) return null;
    if (node.id == id) return node;
    for (var child in node.children) {
      final found = findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  void reorderGraphChildren(String parentId, int oldIndex, int newIndex) {
    final newTree = reorderProjectChildren(
      parentId: parentId,
      oldIndex: BigInt.from(oldIndex),
      newIndex: BigInt.from(newIndex),
    );
    projectTree.value = newTree;
  }

  /// Resolves the nearest valid parent Graph node ID (NodeType.plot).
  /// If no graph is found, returns null.
  String? getValidParentGraphId() {
    final selectedId = selectedProjectNodeId.value;
    final root = projectTree.value;
    if (root == null) return null;

    if (selectedId != null) {
      final selectedNode = findNodeById(root, selectedId);
      if (selectedNode != null) {
        if (selectedNode.nodeType == NodeType.plot) return selectedNode.id;
        // If selected is a dataset, try to find its parent graph
        final parent = _findParentOfNode(root, selectedId);
        if (parent != null && parent.nodeType == NodeType.plot) {
          return parent.id;
        }
      }
    }

    // Fallback: return the first graph in the tree
    return _findFirstGraphNode(root);
  }

  ProjectNode? _findParentOfNode(ProjectNode root, String nodeId) {
    for (var child in root.children) {
      if (child.id == nodeId) return root;
      final found = _findParentOfNode(child, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  String? _findFirstGraphNode(ProjectNode node) {
    if (node.nodeType == NodeType.plot) return node.id;
    for (var child in node.children) {
      final found = _findFirstGraphNode(child);
      if (found != null) return found;
    }
    return null;
  }

  /// Fetch tables for a graph from Rust and update activeTables.
  void fetchTablesForGraph(String graphId) {
    try {
      final tables = getTablesForGraph(graphId: graphId);
      activeTables.value = tables;
      // Also set legacy activeTable to first table if present to avoid breaking
      if (tables.isNotEmpty) {
        activeTable.value = tables.first;
        tableDisplayName.value = tables.first.name;
      } else {
        // Clear stale table from previous graph
        activeTable.value = null;
      }
    } catch (e) {
      // Keep previous state on error
    }
  }

  void handleDataImport(String raw, String displayName) {
    final parentId = getValidParentGraphId();
    if (parentId == null) {
      debugPrint("No valid graph found to import data into.");
      return;
    }

    // Perform insertion
    final newTree = addTableFromRaw(
      parentId: parentId,
      raw: raw,
      displayName: displayName,
    );
    projectTree.value = newTree;

    // Refresh chart + selection directly (mirrors handlePaste pattern)
    selectedProjectNodeId.value = parentId;
    final root = projectTree.value;
    final graph = root != null ? findNodeById(root, parentId) : null;
    if (graph != null) {
      graphName.value = graph.name;
    }
    fetchTablesForGraph(parentId);
  }

  /// Handles paste operations by either updating an existing selected table
  /// or creating a new table node within the currently active graph.
  void handlePaste(String rawText, {String? displayName}) {
    final root = projectTree.value;

    // 1. If an active table exists, update it.
    if (activeTable.value != null) {
      final tableId = activeTable.value!.id;
      updateTableFromRaw(tableId: tableId, raw: rawText);

      // If a displayName is provided (e.g., "Pasted Table"), rename the node.
      if (displayName != null) {
        renameProjectNodeWrapper(tableId, displayName);
      }

      // Refresh the table data
      final updatedTable = getTable(tableId: tableId);
      activeTable.value = updatedTable;
      tableDisplayName.value = updatedTable.name;

      final parentGraph = _findParentOfNode(root!, tableId);
      if (parentGraph != null) {
        fetchTablesForGraph(parentGraph.id);
      }
      return;
    }

    // 2. Fallback: Import as new data node into current graph
    handleDataImport(rawText, displayName ?? 'Pasted Table');
  }

  void deleteProjectNodeWrapper(String nodeId) {
    final newTree = deleteProjectNode(nodeId: nodeId);
    projectTree.value = newTree;

    // Clean up active selections if deleted
    if (selectedProjectNodeId.value == nodeId) {
      selectedProjectNodeId.value = null;
      activeTable.value = getEmptyTableData();
      activeTables.value = [];
    } else {
      // If we deleted a table that was currently the activeTable
      if (activeTable.value?.id == nodeId) {
        activeTable.value = getEmptyTableData();
      }

      // If the selected node is a graph, we should refresh its tables because one of its children might have been deleted
      final stillSelected = findNodeById(
        newTree,
        selectedProjectNodeId.value ?? '',
      );
      if (stillSelected != null && stillSelected.nodeType == NodeType.plot) {
        fetchTablesForGraph(stillSelected.id);
      }
    }
  }

  void renameProjectNodeWrapper(String nodeId, String newName) {
    final newTree = renameProjectNode(nodeId: nodeId, newName: newName);
    projectTree.value = newTree;
    // Also update legacy names if editing the default items
    if (nodeId == 'table_1') tableName.value = newName;
    if (nodeId == 'graph_1') graphName.value = newName;
  }
}
