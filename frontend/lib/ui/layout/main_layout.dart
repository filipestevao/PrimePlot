import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import '../../core/theme.dart';
import 'custom_title_bar.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late MultiSplitViewController _controller;

  @override
  void initState() {
    super.initState();
    // Configure initial weights for Left (Explorer), Center (Canvas), Right (Properties)
    _controller = MultiSplitViewController(
      areas: [
        Area(weight: 0.2, minimalWeight: 0.1),
        Area(weight: 0.6, minimalWeight: 0.3),
        Area(weight: 0.2, minimalWeight: 0.1),
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
              child: MultiSplitView(
                controller: _controller,
                children: [
                  // Left Panel: Project Explorer & Layers
                  _buildPanel('Project Explorer\n&\nLayer Stack'),
                  // Center Panel: Plotting Canvas
                  _buildPanel('Central Canvas\n(High-Performance Rendering)'),
                  // Right Panel: Contextual Properties
                  _buildPanel('Property Inspector'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(String title) {
    return Container(
      color: PrimeTheme.panelBackground,
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: PrimeTheme.textSecondary),
        ),
      ),
    );
  }
}
