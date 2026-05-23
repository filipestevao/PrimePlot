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

  const PlotProperties({
    required this.lineColor,
    required this.lineThickness,
    required this.showGrid,
    required this.xAxisLabel,
    required this.yAxisLabel,
    this.aspectRatio,
  });

  PlotProperties copyWith({
    Color? lineColor,
    double? lineThickness,
    bool? showGrid,
    String? xAxisLabel,
    String? yAxisLabel,
    double? Function()? aspectRatio,
  }) {
    return PlotProperties(
      lineColor: lineColor ?? this.lineColor,
      lineThickness: lineThickness ?? this.lineThickness,
      showGrid: showGrid ?? this.showGrid,
      xAxisLabel: xAxisLabel ?? this.xAxisLabel,
      yAxisLabel: yAxisLabel ?? this.yAxisLabel,
      aspectRatio: aspectRatio != null ? aspectRatio() : this.aspectRatio,
    );
  }
}

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

  // Layer Stack State
  final ValueNotifier<List<LayerItem>> layers = ValueNotifier([]);

  // Plot Properties State
  final ValueNotifier<PlotProperties> plotProperties = ValueNotifier(
    const PlotProperties(
      lineColor: Color(0xFF00C3FF), // PrimeTheme.primaryAccent roughly
      lineThickness: 2.5,
      showGrid: true,
      xAxisLabel: 'X',
      yAxisLabel: 'Y',
    )
  );

  void updatePlotProperties(PlotProperties newProps) {
    plotProperties.value = newProps;
  }

  void loadInitialData() {
    // Start with an empty table – Rust is the single source of truth.
    activeTable.value = getEmptyTableData();
    projectTree.value = getProjectTree();

    // Initialize layers. Scatter starts visible (empty table has 0 rows ≤ 10).
    layers.value = [
      LayerItem(id: 'axis', name: 'Axis', iconData: Icons.straighten),
      LayerItem(id: 'scatter_a', name: 'Data Series A (Scatter)', iconData: Icons.scatter_plot),
      LayerItem(id: 'line_a', name: 'Data Series B (Line)', iconData: Icons.timeline),
      LayerItem(id: 'fit_a', name: 'Linear Fit A', iconData: Icons.show_chart),
      LayerItem(id: 'annotation', name: 'Annotation 1 (Arrow)', iconData: Icons.north_east),
      LayerItem(id: 'legend', name: 'Legend', iconData: Icons.list, isVisible: false),
    ];
  }

  /// Parses a raw clipboard string via Rust and updates all dependent state.
  /// This is the single entry-point for paste operations.
  void pasteTable(String rawClipboard) {
    final newTable = parseClipboardTable(raw: rawClipboard);
    activeTable.value = newTable;

    // Count valid rows (non-empty = at least one non-NaN column in that row).
    final rowCount = newTable.columns.isNotEmpty
        ? newTable.columns.first.data.length
        : 0;

    // Delegate the threshold rule to Rust.
    final scatterVisible = applyScatterRule(rowCount: BigInt.from(rowCount));

    final currentLayers = List<LayerItem>.from(layers.value);
    final idx = currentLayers.indexWhere((l) => l.id == 'scatter_a');
    if (idx != -1) {
      currentLayers[idx] = currentLayers[idx].copyWith(isVisible: scatterVisible);
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
