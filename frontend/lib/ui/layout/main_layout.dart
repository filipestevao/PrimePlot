// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/project.dart';
import '../components/panel_container.dart';
import 'custom_title_bar.dart';
import '../panels/project_explorer.dart';
import '../panels/property_inspector.dart';
import '../panels/collapsible_data_panel.dart';
import '../canvas/plot_canvas.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late MultiSplitViewController _mainController;
  late MultiSplitViewController _leftController;
  late MultiSplitViewController _centerController;
  late MultiSplitViewController _rightController;
  bool _isDataPanelCollapsed = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    ProjectState.instance.loadInitialData();
    ProjectState.instance.selectedProjectNodeId.addListener(
      _onSelectionChanged,
    );

    // Left Vertical Split
    _leftController = MultiSplitViewController(
      areas: [
        Area(
          flex: 6,
          builder: (context, area) => PanelContainer(
            title: 'Project Explorer',
            icon: Icons.folder_copy,
            actions: [
              PopupMenuButton<_ExplorerAction>(
                tooltip: 'Add Item',
                icon: const Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: PrimeTheme.textSecondary,
                ),
                color: PrimeTheme.backgroundDark,
                elevation: 8,
                offset: const Offset(0, 30),
                onSelected: (_ExplorerAction action) {
                  switch (action) {
                    case _ExplorerAction.addGraph:
                      final root = ProjectState.instance.projectTree.value;
                      if (root != null) {
                        // Find first folder (not the root_1 pseudo-folder)
                        ProjectNode? targetFolder;
                        void findFolder(ProjectNode node) {
                          if (node.nodeType == NodeType.folder &&
                              node.id != 'root_1') {
                            targetFolder = node;
                            return;
                          }
                          for (var child in node.children) {
                            if (targetFolder != null) return;
                            findFolder(child);
                          }
                        }

                        findFolder(root);
                        String? graphId;
                        if (targetFolder != null) {
                          graphId = ProjectState.instance
                              .addProjectNodeAndReturnId(
                                targetFolder!.id,
                                'Graph',
                                NodeType.plot,
                              );
                        } else {
                          // Auto-create folder first
                          final folderId = ProjectState.instance
                              .addProjectNodeAndReturnId(
                                'root_1',
                                'Folder',
                                NodeType.folder,
                              );
                          graphId = ProjectState.instance
                              .addProjectNodeAndReturnId(
                                folderId,
                                'Graph',
                                NodeType.plot,
                              );
                        }
                        if (graphId.isNotEmpty) {
                          ProjectState.instance.selectProjectNode(graphId);
                        }
                      }
                      break;
                    case _ExplorerAction.addTable:
                    case _ExplorerAction.addFunction:
                    case _ExplorerAction.addShape:
                      final root = ProjectState.instance.projectTree.value;
                      if (root != null) {
                        // Find first graph (inside any folder or at root)
                        ProjectNode? targetGraph;
                        void findGraph(ProjectNode node) {
                          if (node.nodeType == NodeType.plot) {
                            targetGraph = node;
                            return;
                          }
                          for (var child in node.children) {
                            if (targetGraph != null) return;
                            findGraph(child);
                          }
                        }

                        findGraph(root);

                        final nodeType = action == _ExplorerAction.addTable
                            ? NodeType.dataset
                            : action == _ExplorerAction.addFunction
                            ? NodeType.function
                            : NodeType.shape;
                        final defaultName = action == _ExplorerAction.addTable
                            ? 'Table'
                            : action == _ExplorerAction.addFunction
                            ? 'Function'
                            : 'Shape';

                        if (targetGraph != null) {
                          ProjectState.instance.addProjectNodeWrapper(
                            targetGraph!.id,
                            defaultName,
                            nodeType,
                          );
                        } else {
                          // Auto-create folder → graph → item
                          final folderId = ProjectState.instance
                              .addProjectNodeAndReturnId(
                                'root_1',
                                'Folder',
                                NodeType.folder,
                              );
                          final graphId = ProjectState.instance
                              .addProjectNodeAndReturnId(
                                folderId,
                                'Graph',
                                NodeType.plot,
                              );
                          ProjectState.instance.addProjectNodeWrapper(
                            graphId,
                            defaultName,
                            nodeType,
                          );
                        }
                      }
                      break;
                    case _ExplorerAction.addFolder:
                      ProjectState.instance.addProjectNodeWrapper(
                        'root_1',
                        'Folder',
                        NodeType.folder,
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_ExplorerAction>>[
                      const PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addTable,
                        child: Text(
                          'Add Table',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      const PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addFunction,
                        child: Text(
                          'Add Function',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      const PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addShape,
                        child: Text(
                          'Add Shape',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      const PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addGraph,
                        child: Text(
                          'Add Graph',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      const PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addFolder,
                        child: Text(
                          'Add Folder',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                    ],
              ),
            ],
            child: const ProjectExplorer(),
          ),
        ),
      ],
    );

    _centerController = MultiSplitViewController(areas: _buildCenterAreas());

    // Right Vertical Split
    _rightController = MultiSplitViewController(
      areas: [
        Area(
          flex: 3,
          builder: (context, area) => const PanelContainer(
            title: 'Property Inspector',
            icon: Icons.tune,
            child: PropertyInspector(),
          ),
        ),
      ],
    );

    // Main Horizontal Split
    _mainController = MultiSplitViewController(
      areas: [
        Area(
          flex: 2,
          builder: (context, area) =>
              MultiSplitView(controller: _leftController, axis: Axis.vertical),
        ),
        Area(
          flex: 6,
          builder: (context, area) => MultiSplitView(
            controller: _centerController,
            axis: Axis.vertical,
          ),
        ),
        Area(
          flex: 2,
          builder: (context, area) =>
              MultiSplitView(controller: _rightController, axis: Axis.vertical),
        ),
      ],
    );
  }

  List<Area> _buildCenterAreas() {
    bool isTableSelected = false;
    final root = ProjectState.instance.projectTree.value;
    final selectedId = ProjectState.instance.selectedProjectNodeId.value;

    if (root != null && selectedId != null) {
      final node = ProjectState.instance.findNodeById(root, selectedId);
      if (node != null && node.nodeType == NodeType.dataset) {
        isTableSelected = true;
      }
    }

    final areas = <Area>[
      Area(
        flex: _isDataPanelCollapsed || !isTableSelected ? 1 : 3,
        builder: (context, area) => ValueListenableBuilder<String>(
          valueListenable: ProjectState.instance.graphName,
          builder: (context, graphName, child) {
            return PanelContainer(
              title: graphName,
              icon: Icons.show_chart,
              child: const PlotCanvas(),
            );
          },
        ),
      ),
    ];

    if (isTableSelected) {
      areas.add(
        Area(
          flex: _isDataPanelCollapsed ? null : 2,
          size: _isDataPanelCollapsed ? 46 : null,
          min: _isDataPanelCollapsed ? 46 : null,
          builder: (context, area) => CollapsibleDataPanel(
            isCollapsed: _isDataPanelCollapsed,
            onToggle: _toggleDataPanel,
          ),
        ),
      );
    }

    return areas;
  }

  void _onSelectionChanged() {
    setState(() {
      _centerController.areas = _buildCenterAreas();
    });
  }

  void _toggleDataPanel() {
    setState(() {
      _isDataPanelCollapsed = !_isDataPanelCollapsed;
      _centerController.areas = _buildCenterAreas();
    });
  }

  @override
  void dispose() {
    ProjectState.instance.selectedProjectNodeId.removeListener(
      _onSelectionChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _dragging = false;
        });
      },
      onDragDone: (details) async {
        setState(() {
          _dragging = false;
        });
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          try {
            final content = await file.readAsString();
            ProjectState.instance.handleDataImport(content, file.name);
          } catch (e) {
            debugPrint("Error reading dropped file: $e");
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: PrimeTheme.backgroundDark,
            drawer: Drawer(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(16),
                ),
              ),
              backgroundColor: PrimeTheme.panelBackground,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 52, // Match title bar height
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pie_chart,
                            size: 20,
                            color: PrimeTheme.primaryAccent,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'PrimePlot',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PrimeTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: PrimeTheme.borderSide,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(
                      Icons.create_new_folder,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: const Text(
                      'New project',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      debugPrint("Menu Selected: new");
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.folder_open,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: const Text(
                      'Open project',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      debugPrint("Menu Selected: open");
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.save,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: const Text(
                      'Save',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      debugPrint("Menu Selected: save");
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.save_as,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: const Text(
                      'Save as...',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      debugPrint("Menu Selected: save_as");
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(
                    height: 16,
                    thickness: 1,
                    color: PrimeTheme.borderSide,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: const Text(
                      'Settings',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      debugPrint("Menu Selected: settings");
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: const Text(
                      'About',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      debugPrint("Menu Selected: about");
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                const CustomTitleBar(),
                Expanded(
                  child: MultiSplitViewTheme(
                    data: MultiSplitViewThemeData(
                      dividerPainter: DividerPainters.grooved1(
                        color: PrimeTheme.borderSide,
                        highlightedColor: PrimeTheme.primaryAccent,
                        size: 2,
                      ),
                    ),
                    child: Container(
                      color:
                          PrimeTheme.backgroundDark, // Reveal floating effect
                      padding: const EdgeInsets.all(
                        4.0,
                      ), // Padding from window edge
                      child: MultiSplitView(
                        controller: _mainController,
                        axis: Axis.horizontal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_dragging)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: PrimeTheme.backgroundDark.withValues(
                                alpha: 0.9,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PrimeTheme.primaryAccent.withValues(
                                  alpha: 0.8,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PrimeTheme.primaryAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.file_present_rounded,
                              size: 56,
                              color: PrimeTheme.primaryAccent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "drop the file here",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: PrimeTheme.textPrimary,
                              letterSpacing: 0.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "CSV or TXT format datasets",
                            style: TextStyle(
                              fontSize: 14,
                              color: PrimeTheme.textSecondary.withValues(
                                alpha: 0.8,
                              ),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Actions for the Project Explorer "Add Item" popup menu.
enum _ExplorerAction { addGraph, addTable, addFunction, addShape, addFolder }
