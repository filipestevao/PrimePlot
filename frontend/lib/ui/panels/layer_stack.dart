// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/state.dart';

class LayerStack extends StatelessWidget {
  const LayerStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PrimeTheme.panelBackground,
      child: Column(
        children: [
          // Grid toggle pinned at the top
          ValueListenableBuilder<PlotProperties>(
            valueListenable: ProjectState.instance.plotProperties,
            builder: (context, props, child) {
              return ListTile(
                dense: true,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                contentPadding: const EdgeInsets.only(left: 16.0, right: 8.0, top: 4, bottom: 4),
                leading: const Icon(
                  Icons.grid_on,
                  size: 16,
                  color: PrimeTheme.textSecondary,
                ),
                title: const Text(
                  'Grid',
                  style: TextStyle(fontSize: 13, color: PrimeTheme.textPrimary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        props.showGrid ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                        color: props.showGrid
                            ? PrimeTheme.textSecondary
                            : PrimeTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () {
                        ProjectState.instance.updatePlotProperties(
                          props.copyWith(showGrid: !props.showGrid),
                        );
                      },
                    ),
                    // Spacer to align with layer drag handles below
                    const SizedBox(width: 24),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: PrimeTheme.borderSide),

          // Reorderable layer list
          Expanded(
            child: ValueListenableBuilder<List<LayerItem>>(
              valueListenable: ProjectState.instance.layers,
              builder: (context, layers, child) {
                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: layers.length,
                  onReorder: (oldIndex, newIndex) {
                    ProjectState.instance.reorderLayers(oldIndex, newIndex);
                  },
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    return Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: PrimeTheme.backgroundDark.withOpacity(0.8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    final bool isVisible = layer.isVisible;
                    final bool isSelected = layer.isSelected;

                    return Material(
                      key: ValueKey(layer.id),
                      color: isSelected
                          ? PrimeTheme.primaryAccent.withOpacity(0.15)
                          : Colors.transparent,
                      child: ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                        leading: Icon(
                          layer.iconData,
                          size: 16,
                          color: isSelected
                              ? PrimeTheme.primaryAccent
                              : PrimeTheme.textSecondary,
                        ),
                        title: Text(
                          layer.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: isVisible
                                ? (isSelected
                                    ? PrimeTheme.primaryAccent
                                    : PrimeTheme.textPrimary)
                                : PrimeTheme.textSecondary.withValues(alpha: 0.5),
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isVisible ? Icons.visibility : Icons.visibility_off,
                                size: 16,
                                color: isVisible
                                    ? PrimeTheme.textSecondary
                                    : PrimeTheme.textSecondary.withOpacity(0.3),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                              onPressed: () {
                                ProjectState.instance.toggleLayerVisibility(layer.id);
                              },
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.drag_handle,
                              size: 16,
                              color: PrimeTheme.textSecondary.withOpacity(0.5),
                            ),
                          ],
                        ),
                        onTap: () {
                          ProjectState.instance.selectLayer(layer.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
