import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import '../../core/theme.dart';
import '../../core/state.dart';
import '../../src/rust/api/project.dart';
import '../components/panel_container.dart';
import 'custom_title_bar.dart';
import '../panels/project_explorer.dart';
import '../panels/layer_stack.dart';
import '../panels/data_table_panel.dart';
import '../panels/property_inspector.dart';
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

  @override
  void initState() {
    super.initState();
    ProjectState.instance.loadInitialData();
    
    // Left Vertical Split
    _leftController = MultiSplitViewController(
      areas: [
        Area(flex: 6, builder: (context, area) => PanelContainer(
          title: 'Project Explorer',
          icon: Icons.folder_copy,
          actions: [
            PopupMenuButton<NodeType>(
              tooltip: 'Add Item',
              icon: const Icon(Icons.more_horiz, size: 16, color: PrimeTheme.textSecondary),
              color: PrimeTheme.backgroundDark,
              elevation: 8,
              offset: const Offset(0, 30),
              onSelected: (NodeType type) {
                ProjectState.instance.addProjectNodeWrapper('root_1', 'New Item', type);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<NodeType>>[
                const PopupMenuItem<NodeType>(value: NodeType.folder, child: Text('Add Folder', style: TextStyle(color: PrimeTheme.textPrimary))),
                const PopupMenuItem<NodeType>(value: NodeType.dataset, child: Text('Add Table', style: TextStyle(color: PrimeTheme.textPrimary))),
                const PopupMenuItem<NodeType>(value: NodeType.plot, child: Text('Add Graph', style: TextStyle(color: PrimeTheme.textPrimary))),
              ],
            ),
          ],
          child: const ProjectExplorer(),
        )),
        Area(flex: 4, builder: (context, area) => const PanelContainer(
          title: 'Layer Stack',
          icon: Icons.layers,
          child: LayerStack(),
        )),
      ],
    );

    // Center Horizontal Split
    _centerController = MultiSplitViewController(
      areas: [
        Area(flex: 4, builder: (context, area) => ValueListenableBuilder<String>(
          valueListenable: ProjectState.instance.tableName,
          builder: (context, tableName, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: ProjectState.instance.isTableEditable,
              builder: (context, isEditable, child) {
                return PanelContainer(
                  title: tableName,
                  icon: Icons.table_chart,
                  actions: [
                    IconButton(
                      icon: Icon(
                        isEditable ? Icons.lock_open : Icons.lock,
                        size: 14,
                        color: isEditable ? PrimeTheme.primaryAccent : PrimeTheme.textSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () {
                        ProjectState.instance.toggleTableEditMode();
                      },
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.more_horiz, size: 16, color: PrimeTheme.textSecondary),
                    const SizedBox(width: 8),
                    const Icon(Icons.close, size: 14, color: PrimeTheme.textSecondary),
                  ],
                  child: const DataTablePanel(),
                );
              }
            );
          }
        )),
        Area(flex: 6, builder: (context, area) => ValueListenableBuilder<String>(
          valueListenable: ProjectState.instance.graphName,
          builder: (context, graphName, child) {
            return PanelContainer(
              title: graphName,
              icon: Icons.show_chart,
              child: const PlotCanvas(),
            );
          }
        )),
      ],
    );

    // Main Horizontal Split
    _mainController = MultiSplitViewController(
      areas: [
        Area(flex: 2, builder: (context, area) => MultiSplitView(controller: _leftController, axis: Axis.vertical)),
        Area(flex: 6, builder: (context, area) => MultiSplitView(controller: _centerController, axis: Axis.horizontal)),
        Area(flex: 2, builder: (context, area) => const PanelContainer(
          title: 'Property Inspector',
          icon: Icons.tune,
          child: PropertyInspector(),
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimeTheme.backgroundDark,
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
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
                    const Icon(Icons.pie_chart, size: 20, color: PrimeTheme.primaryAccent),
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
            const Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.folder_open, size: 18, color: PrimeTheme.textSecondary),
              title: const Text('Open project', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
              onTap: () {
                debugPrint("Menu Selected: open");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save, size: 18, color: PrimeTheme.textSecondary),
              title: const Text('Save', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
              onTap: () {
                debugPrint("Menu Selected: save");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_as, size: 18, color: PrimeTheme.textSecondary),
              title: const Text('Save as...', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
              onTap: () {
                debugPrint("Menu Selected: save_as");
                Navigator.pop(context);
              },
            ),
            const Divider(height: 16, thickness: 1, color: PrimeTheme.borderSide),
            ListTile(
              leading: const Icon(Icons.settings, size: 18, color: PrimeTheme.textSecondary),
              title: const Text('Settings', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
              onTap: () {
                debugPrint("Menu Selected: settings");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, size: 18, color: PrimeTheme.textSecondary),
              title: const Text('About', style: TextStyle(color: PrimeTheme.textPrimary, fontSize: 13)),
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
                color: PrimeTheme.backgroundDark, // Reveal floating effect
                padding: const EdgeInsets.all(4.0), // Padding from window edge
                child: MultiSplitView(
                  controller: _mainController,
                  axis: Axis.horizontal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
