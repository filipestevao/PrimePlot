import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import '../../core/theme.dart';
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
    
    // Left Vertical Split
    _leftController = MultiSplitViewController(
      areas: [
        Area(flex: 6, builder: (context, area) => const PanelContainer(
          title: 'Project Explorer',
          icon: Icons.folder_copy,
          child: ProjectExplorer(),
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
        Area(flex: 4, builder: (context, area) => const PanelContainer(
          title: 'Data: Exp101.csv',
          icon: Icons.table_chart,
          child: DataTablePanel(),
        )),
        Area(flex: 6, builder: (context, area) => const PanelContainer(
          title: 'Plot: Analysis View',
          icon: Icons.show_chart,
          child: PlotCanvas(),
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
