import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import '../../core/theme.dart';
import 'custom_title_bar.dart';
import '../panels/project_explorer.dart';

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
    _controller = MultiSplitViewController(
      areas: [
        Area(flex: 2, builder: (context, area) => const ProjectExplorer()),
        Area(flex: 6, builder: (context, area) => _buildPanel('Central Canvas\n(High-Performance Rendering)')),
        Area(flex: 2, builder: (context, area) => _buildPanel('Property Inspector')),
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
