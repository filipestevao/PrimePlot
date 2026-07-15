// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../src/rust/api/data.dart';
import '../src/rust/api/project.dart';

class LayerItem {
  final String id;
  final String name;
  final IconData iconData;
  final bool isVisible;
  final bool isSelected;

  LayerItem({
    required this.id,
    required this.name,
    required this.iconData,
    this.isVisible = true,
    this.isSelected = false,
  });

  LayerItem copyWith({
    String? id,
    String? name,
    IconData? iconData,
    bool? isVisible,
    bool? isSelected,
  }) {
    return LayerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      iconData: iconData ?? this.iconData,
      isVisible: isVisible ?? this.isVisible,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class PlotProperties {
  final Color lineColor;
  final double lineThickness;
  final bool showGrid;
  final String xAxisLabel;
  final String yAxisLabel;
  final double? aspectRatio;
  final double? xMin;
  final double? xMax;
  final double? yMin;
  final double? yMax;

  const PlotProperties({
    required this.lineColor,
    required this.lineThickness,
    required this.showGrid,
    required this.xAxisLabel,
    required this.yAxisLabel,
    this.aspectRatio,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
  });

  PlotProperties copyWith({
    Color? lineColor,
    double? lineThickness,
    bool? showGrid,
    String? xAxisLabel,
    String? yAxisLabel,
    double? Function()? aspectRatio,
    double? Function()? xMin,
    double? Function()? xMax,
    double? Function()? yMin,
    double? Function()? yMax,
  }) {
    return PlotProperties(
      lineColor: lineColor ?? this.lineColor,
      lineThickness: lineThickness ?? this.lineThickness,
      showGrid: showGrid ?? this.showGrid,
      xAxisLabel: xAxisLabel ?? this.xAxisLabel,
      yAxisLabel: yAxisLabel ?? this.yAxisLabel,
      aspectRatio: aspectRatio != null ? aspectRatio() : this.aspectRatio,
      xMin: xMin != null ? xMin() : this.xMin,
      xMax: xMax != null ? xMax() : this.xMax,
      yMin: yMin != null ? yMin() : this.yMin,
      yMax: yMax != null ? yMax() : this.yMax,
    );
  }
}

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

  // Layer Stack State
  final ValueNotifier<List<LayerItem>> layers = ValueNotifier([]);

  // Plot Properties State
  final Map<String, PlotProperties> _graphProperties = {};
  
  static const PlotProperties _defaultPlotProperties = PlotProperties(
    lineColor: Color(0xFF00C3FF), // PrimeTheme.primaryAccent roughly
    lineThickness: 2.5,
    showGrid: true,
    xAxisLabel: 'X',
    yAxisLabel: 'Y',
  );

  final ValueNotifier<PlotProperties> plotProperties = ValueNotifier(_defaultPlotProperties);

  void updatePlotProperties(PlotProperties newProps) {
    plotProperties.value = newProps;
    final activePlotId = _getActivePlotId();
    if (activePlotId != null) {
      _graphProperties[activePlotId] = newProps;
    }
  }

  String? _getActivePlotId() {
    final root = projectTree.value;
    final selectedId = selectedProjectNodeId.value;
    if (root == null || selectedId == null) return null;
    
    final node = _findNodeById(root, selectedId);
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

    // Initialize layers. Scatter starts visible (empty table has 0 rows ≤ 10).
    layers.value = [
      LayerItem(id: 'grid', name: 'Grid', iconData: Icons.grid_on),
      LayerItem(id: 'axis', name: 'Axis', iconData: Icons.straighten),
      LayerItem(id: 'scatter_a', name: 'Data Series A (Scatter)', iconData: Icons.scatter_plot),
      LayerItem(id: 'line_a', name: 'Data Series B (Line)', iconData: Icons.timeline),
      LayerItem(id: 'fit_a', name: 'Linear Fit A', iconData: Icons.show_chart),
      LayerItem(id: 'annotation', name: 'Annotation 1 (Arrow)', iconData: Icons.north_east),
      LayerItem(id: 'legend', name: 'Legend', iconData: Icons.list, isVisible: false),
    ];
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

    final rowCount = parsed.columns.isNotEmpty
        ? parsed.columns.first.data.length
        : 0;
    final scatterVisible = applyScatterRule(rowCount: BigInt.from(rowCount));
    _setScatterVisible(scatterVisible);
  }

  /// Creates a new blank 10-row × 2-column table in the active graph.
  void newTable() {
    final parentId = getValidParentGraphId();
    if (parentId == null) return;

    final active = activeTable.value;
    final isEmptyTable = active != null &&
        active.columns.every((c) => c.data.isEmpty);

    if (isEmptyTable) {
      final newColumns = active!.columns.map((col) => DTODataColumn(
        name: col.name,
        role: col.role,
        data: Float64List.fromList(List.generate(10, (_) => double.nan)),
      )).toList();
      saveTable(tableId: active.id, columns: newColumns);
      final updated = getTable(tableId: active.id);
      activeTable.value = updated;
      tableDisplayName.value = updated.name;
      _setScatterVisible(true);
      return;
    }

    final newTree = addEmptyTable(parentId: parentId, name: 'Table', rowCount: BigInt.from(10), colCount: BigInt.from(2));
    projectTree.value = newTree;
    final root = projectTree.value;
    final parent = _findNodeById(root, parentId);
    if (parent != null && parent.children.isNotEmpty) {
      final newNode = parent.children.last;
      selectProjectNode(newNode.id);
    }
    _setScatterVisible(true);
  }

  /// Clears all data rows, keeping the column schema, resetting to an empty table.
  void clearTableData() {
    final active = activeTable.value;
    if (active == null) return;
    final newColumns = active.columns.map((col) => DTODataColumn(
      name: col.name,
      role: col.role,
      data: Float64List(0),
    )).toList();
    saveTable(tableId: active.id, columns: newColumns);
    final updated = getTable(tableId: active.id);
    activeTable.value = updated;
    tableDisplayName.value = updated.name;
    _setScatterVisible(true);
  }

  void _setScatterVisible(bool visible) {
    final currentLayers = List<LayerItem>.from(layers.value);
    final idx = currentLayers.indexWhere((l) => l.id == 'scatter_a');
    if (idx != -1) {
      currentLayers[idx] = currentLayers[idx].copyWith(isVisible: visible);
      layers.value = currentLayers;
    }
  }

  void toggleLayerVisibility(String id) {
    final currentLayers = List<LayerItem>.from(layers.value);
    final index = currentLayers.indexWhere((l) => l.id == id);
    if (index != -1) {
      currentLayers[index] = currentLayers[index].copyWith(isVisible: !currentLayers[index].isVisible);
      layers.value = currentLayers;
    }
  }

  void selectLayer(String id) {
    final currentLayers = List<LayerItem>.from(layers.value);
    for (int i = 0; i < currentLayers.length; i++) {
      currentLayers[i] = currentLayers[i].copyWith(isSelected: currentLayers[i].id == id);
    }
    layers.value = currentLayers;
  }

  void reorderLayers(int oldIndex, int newIndex) {
    final currentLayers = List<LayerItem>.from(layers.value);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = currentLayers.removeAt(oldIndex);
    currentLayers.insert(newIndex, item);
    layers.value = currentLayers;
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
    final newTree = addProjectNode(parentId: parentId, name: name, nodeType: type);
    projectTree.value = newTree;
  }

  /// Adds a project node and returns its generated ID.
  String addProjectNodeAndReturnId(String parentId, String name, NodeType type) {
    final newTree = addProjectNode(parentId: parentId, name: name, nodeType: type);
    projectTree.value = newTree;
    // New node is the last child of parent with the matching type
    final parent = _findNodeById(newTree, parentId);
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
    ProjectNode? node = _findNodeById(root, nodeId);
    if (node != null) {
      // Switch plot properties context
      String? plotId;
      if (node.nodeType == NodeType.plot) {
        plotId = node.id;
      } else if (node.nodeType == NodeType.dataset) {
        if (root != null) {
          final parent = _findParentById(root, node.id);
          if (parent != null && parent.nodeType == NodeType.plot) {
            plotId = parent.id;
          }
        }
      }
      if (plotId != null) {
        plotProperties.value = _graphProperties[plotId] ?? _defaultPlotProperties;
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
          // Set scatter visibility according to table row count (Rust rule)
          final rowCount = table.columns.isNotEmpty ? table.columns.first.data.length : 0;
          final scatterVisible = applyScatterRule(rowCount: BigInt.from(rowCount));
          _setScatterVisible(scatterVisible);
          // Clear multi-table view so canvas shows single table
          activeTables.value = [];
        } catch (e) {
          // ignore and keep existing state
        }
      }
    }
  }

  ProjectNode? _findNodeById(ProjectNode? node, String id) {
    if (node == null) return null;
    if (node.id == id) return node;
    for (var child in node.children) {
      final found = _findNodeById(child, id);
      if (found != null) return found;
    }
    return null;
  }

  void reorderGraphChildren(String parentId, int oldIndex, int newIndex) {
    final newTree = reorderProjectChildren(parentId: parentId, oldIndex: BigInt.from(oldIndex), newIndex: BigInt.from(newIndex));
    projectTree.value = newTree;
  }

  /// Resolves the nearest valid parent Graph node ID (NodeType.plot).
  /// If no graph is found, returns null.
  String? getValidParentGraphId() {
    final selectedId = selectedProjectNodeId.value;
    final root = projectTree.value;
    if (root == null) return null;

    if (selectedId != null) {
      final selectedNode = _findNodeById(root, selectedId);
      if (selectedNode != null) {
        if (selectedNode.nodeType == NodeType.plot) return selectedNode.id;
        // If selected is a dataset, try to find its parent graph
        final parent = _findParentOfNode(root, selectedId);
        if (parent != null && parent.nodeType == NodeType.plot) return parent.id;
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
        // Determine scatter visibility based on plotted graph point count.
        // Use max row count across tables (plotted graph size).
        int maxRows = 0;
        for (final t in tables) {
          final rows = t.columns.isNotEmpty ? t.columns.first.data.length : 0;
          if (rows > maxRows) maxRows = rows;
        }
        final scatterVisible = applyScatterRule(rowCount: BigInt.from(maxRows));
        _setScatterVisible(scatterVisible);
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
    final newTree = addTableFromRaw(parentId: parentId, raw: raw, displayName: displayName);
    projectTree.value = newTree;
    
    // Refresh chart + selection directly (mirrors handlePaste pattern)
    selectedProjectNodeId.value = parentId;
    final root = projectTree.value;
    final graph = root != null ? _findNodeById(root, parentId) : null;
    if (graph != null) {
      graphName.value = graph.name;
    }
    fetchTablesForGraph(parentId);
  }

  /// Handles paste operations by either updating an existing selected table
  /// or creating a new table node within the currently active graph.
  void handlePaste(String rawText, {String? displayName}) {
    final selectedNodeId = selectedProjectNodeId.value;
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
    final rootBefore = projectTree.value;
    final parentBefore = rootBefore != null ? _findParentOfNode(rootBefore, nodeId) : null;

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
      final stillSelected = _findNodeById(newTree, selectedProjectNodeId.value ?? '');
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
