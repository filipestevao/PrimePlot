// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/file_actions.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/project.dart';
import '../components/panel_container.dart';
import '../dialogs/about_dialog.dart';
import 'custom_title_bar.dart';
import 'status_bar.dart';
import '../panels/project_explorer.dart';
import '../panels/property_inspector.dart';
import '../panels/collapsible_data_panel.dart';
import '../canvas/plot_canvas.dart';
import '../dialogs/settings_dialog.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

/// Hard floor for the whole window. Enforced twice: via
/// `setMinimumSize` in `main()` (compositor hint) and via `onWindowResize`
/// clamping below (some Wayland compositors ignore the hint while a
/// divider/window drag is in flight).
const kMinWindowSize = Size(1024, 600);

class _MainLayoutState extends State<MainLayout> with WindowListener {
  late MultiSplitViewController _mainController;
  late MultiSplitViewController _leftController;
  late MultiSplitViewController _centerController;
  late MultiSplitViewController _rightController;
  bool _isDataPanelCollapsed = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Route every close request (X button, Alt+F4, taskbar) through
    // onWindowClose so dirty state always gets a save prompt.
    windowManager.setPreventClose(true);
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
                icon: Icon(
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
                      PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addTable,
                        child: Text(
                          'Add Table',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addFunction,
                        child: Text(
                          'Add Function',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addShape,
                        child: Text(
                          'Add Shape',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      PopupMenuItem<_ExplorerAction>(
                        value: _ExplorerAction.addGraph,
                        child: Text(
                          'Add Graph',
                          style: TextStyle(color: PrimeTheme.textPrimary),
                        ),
                      ),
                      PopupMenuItem<_ExplorerAction>(
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

    // Main Horizontal Split. Pane minimums are resize STOPS (they sum to
    // ~630px incl. dividers/padding, well under the 1024px window minimum,
    // so dividers always have room and stop cleanly instead of fighting).
    // Sides share flex 2/2 for visual symmetry. Do NOT remove the mins:
    // without them panes shrink until inner Rows overflow and stripe.
    _mainController = MultiSplitViewController(
      areas: [
        Area(
          flex: 2,
          min: 2,
          builder: (context, area) =>
              MultiSplitView(controller: _leftController, axis: Axis.vertical),
        ),
        Area(
          flex: 6,
          min: 2,
          builder: (context, area) => MultiSplitView(
            controller: _centerController,
            axis: Axis.vertical,
          ),
        ),
        Area(
          flex: 2,
          min: 2,
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

  /// Single-key shortcuts must not fire while typing in a text field.
  static void _guardedText(VoidCallback action) {
    final focus = FocusManager.instance.primaryFocus;
    final widget = focus?.context?.widget;
    if (widget is EditableText) return;
    action();
  }

  OverlayEntry? _helpEntry;

  void _toggleShortcutHelp() {
    if (_helpEntry != null) {
      _hideShortcutHelp();
      return;
    }
    _helpEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideShortcutHelp,
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  _hideShortcutHelp();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: const _ShortcutHelpCard(),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_helpEntry!);
  }

  void _hideShortcutHelp() {
    _helpEntry?.remove();
    _helpEntry = null;
  }

  /// Runtime backstop for the minimum window size: if a resize lands below
  /// the floor (hint ignored), snap back. Clamp-only, so no event loop.
  @override
  void onWindowResize() async {
    if (!mounted) return;
    final size = await windowManager.getSize();
    final w = size.width < kMinWindowSize.width
        ? kMinWindowSize.width
        : size.width;
    final h = size.height < kMinWindowSize.height
        ? kMinWindowSize.height
        : size.height;
    if (w != size.width || h != size.height) {
      await windowManager.setSize(Size(w, h));
    }
  }

  @override
  void dispose() {
    _hideShortcutHelp();
    windowManager.removeListener(this);
    ProjectState.instance.selectedProjectNodeId.removeListener(
      _onSelectionChanged,
    );
    super.dispose();
  }

  /// Single choke point for window close: prompts to save when dirty.
  /// Must call [WindowManager.destroy] (not `close`) to exit, since close
  /// is intercepted while prevent-close is set.
  @override
  void onWindowClose() async {    var mayExit = true;
    if (mounted) {
      mayExit = await FileActions.confirmUnsavedChanges(context, 'exiting');
    }
    if (!mayExit && mounted) return;
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            FileActions.doNew(context),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            FileActions.doOpen(context),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            FileActions.doSave(context),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): () => FileActions.doSaveAs(context),
        const SingleActivator(LogicalKeyboardKey.keyS): () =>
            _guardedText(() {
              ProjectState.instance.showStatsHud.value =
                  !ProjectState.instance.showStatsHud.value;
            }),
        const SingleActivator(LogicalKeyboardKey.keyR): () =>
            _guardedText(
                () => ProjectState.instance.resetActiveView()),
        const SingleActivator(LogicalKeyboardKey.slash, shift: true): () =>
            _guardedText(() => _toggleShortcutHelp()),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            _toggleShortcutHelp(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _guardedText(() {
              if (_helpEntry != null) {
                _hideShortcutHelp();
              } else {
                ProjectState.instance.clearSelection();
              }
            }),
      },
      child: Focus(
        autofocus: true,
        child: DropTarget(
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
                          Icon(
                            Icons.pie_chart,
                            size: 20,
                            color: PrimeTheme.primaryAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
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
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: PrimeTheme.borderSide,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Icon(
                      Icons.create_new_folder,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: Text(
                      'New project',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      FileActions.doNew(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.folder_open,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: Text(
                      'Open project',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      FileActions.doOpen(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.save,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: Text(
                      'Save',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      FileActions.doSave(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.save_as,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: Text(
                      'Save as...',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      FileActions.doSaveAs(context);
                    },
                  ),
                  Divider(
                    height: 16,
                    thickness: 1,
                    color: PrimeTheme.borderSide,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.settings,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: Text(
                      'Settings',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => const SettingsDialog(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: PrimeTheme.textSecondary,
                    ),
                    title: Text(
                      'About',
                      style: TextStyle(
                        color: PrimeTheme.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => const PrimeAboutDialog(),
                      );
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
                const StatusBar(),
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
                            child: Icon(
                              Icons.file_present_rounded,
                              size: 56,
                              color: PrimeTheme.primaryAccent,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
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
        ),
      ),
    );
  }
}

/// Actions for the Project Explorer "Add Item" popup menu.
enum _ExplorerAction { addGraph, addTable, addFunction, addShape, addFolder }

/// Non-modal keyboard shortcut reference (toggles with ? / Ctrl+/,
/// dismisses on any key or click-away).
class _ShortcutHelpCard extends StatelessWidget {
  const _ShortcutHelpCard();

  static const _rows = [
    ('Ctrl + N', 'New project'),
    ('Ctrl + O', 'Open project'),
    ('Ctrl + S', 'Save project'),
    ('Ctrl + Shift + S', 'Save project as…'),
    ('S', 'Toggle series statistics'),
    ('R', 'Reset view to home ranges'),
    ('Esc', 'Clear selection'),
    ('Ctrl + /  or  ?', 'This shortcut map'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: PrimeTheme.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PrimeTheme.borderSide),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEYBOARD SHORTCUTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: PrimeTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final (keys, action) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      keys,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: PrimeTheme.primaryAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 12,
                        color: PrimeTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Press any key to dismiss.',
            style: TextStyle(fontSize: 11, color: PrimeTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
