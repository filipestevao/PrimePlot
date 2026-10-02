// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Export dialog with Figure (PNG) and Data (CSV/TSV) tabs, plus helpers to
//! open it on a tab and to copy the figure to the system clipboard.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/export.dart' as xp;
import '../../src/rust/api/project.dart';
import '../canvas/canvas_capture.dart';
import '../components/prime_number_field.dart';
import '../components/prime_select.dart';
import '../components/prime_switch.dart';

class ExportDataset {
  final String id;
  final String name;
  const ExportDataset(this.id, this.name);
}

/// Opens the export dialog. [initialTab]: 0 = Figure, 1 = Data.
void openExportDialog(BuildContext context, int initialTab) {
  final st = ProjectState.instance;
  final box = st.canvasCaptureKey.currentContext?.findRenderObject()
      as RenderBox?;
  final canvasSize = (box != null && box.hasSize && box.size.width > 0)
      ? box.size
      : const Size(800, 600);

  final root = st.projectTree.value;
  final plotId = st.activePlotId;
  final plotNode =
      (root != null && plotId != null) ? st.findNodeById(root, plotId) : null;
  final datasets = <ExportDataset>[];
  String graphName = 'figure';
  if (plotNode != null) {
    graphName = plotNode.name;
    for (final c in plotNode.children) {
      if (c.nodeType == NodeType.dataset) {
        datasets.add(ExportDataset(c.id, c.name));
      }
    }
  }
  final rawBase = st.currentFilePath.value?.split('/').last.split('.').first;
  final defaultName =
      (rawBase != null && rawBase.isNotEmpty) ? rawBase : graphName;

  showDialog(
    context: context,
    builder: (_) => ExportDialog(
      initialTab: initialTab.clamp(0, 1),
      canvasSize: canvasSize,
      graphId: plotId,
      graphName: graphName,
      datasets: datasets,
      defaultName: defaultName,
    ),
  );
}

/// Renders the canvas and places the PNG on the system clipboard.
Future<void> copyFigureToClipboard(BuildContext context) async {
  final bytes = await captureCanvasPng(
    pixelRatio: 2.0,
    background: CanvasExportBackground.theme,
  );
  if (!context.mounted) return;
  if (bytes == null) {
    _snack(context, 'Copy failed: could not render canvas', error: true);
    return;
  }
  try {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      if (!context.mounted) return;
      _snack(context, 'Copy failed: clipboard unavailable', error: true);
      return;
    }
    final item = DataWriterItem();
    item.add(Formats.png(bytes));
    await clipboard.write([item]);
    if (context.mounted) _snack(context, 'Figure copied to clipboard');
  } catch (e) {
    if (!context.mounted) return;
    _snack(context, 'Copy failed: $e', error: true);
  }
}

void _snack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 12)),
      backgroundColor:
          error ? const Color(0xFF7F1D1D) : const Color(0xFF1C2331),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 4 : 2),
    ),
  );
}

class ExportDialog extends StatefulWidget {
  final int initialTab;
  final Size canvasSize;
  final String? graphId;
  final String graphName;
  final List<ExportDataset> datasets;
  final String defaultName;

  const ExportDialog({
    super.key,
    required this.initialTab,
    required this.canvasSize,
    required this.graphId,
    required this.graphName,
    required this.datasets,
    required this.defaultName,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Figure tab state.
  double _dpi = 150;
  CanvasExportBackground _figBg = CanvasExportBackground.theme;
  late final TextEditingController _figName;

  // Data tab state.
  String _dataTarget = 'combined';
  String _dataFormat = 'csv';
  bool _includeHeader = true;
  late final TextEditingController _dataName;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _figName = TextEditingController(text: widget.defaultName);
    _dataName = TextEditingController(text: '${widget.graphName}_data');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _figName.dispose();
    _dataName.dispose();
    super.dispose();
  }

  double get _outScale => _dpi / 96.0;
  int get _outW => (widget.canvasSize.width * _outScale).round();
  int get _outH => (widget.canvasSize.height * _outScale).round();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: PrimeTheme.panelBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PrimeTheme.borderSide),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.ios_share,
                      size: 18, color: PrimeTheme.primaryAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Export',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PrimeTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: PrimeTheme.textSecondary,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: PrimeTheme.borderSide),
            TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Figure'), Tab(text: 'Data')],
              labelColor: PrimeTheme.primaryAccent,
              unselectedLabelColor: PrimeTheme.textSecondary,
              indicatorColor: PrimeTheme.primaryAccent,
              indicatorSize: TabBarIndicatorSize.label,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _busy
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IndexedStack(
                        index: _tabs.index,
                        children: [
                          _figureTab(),
                          _dataTab(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Figure

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: PrimeTheme.textSecondary)),
    );
  }

  Widget _figureTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Format'),
        const _DisabledRow(label: 'PNG', note: 'SVG — coming soon'),
        const SizedBox(height: 10),
        _label('Resolution (DPI) — 72 screen · 150 print · 300 publication'),
        PrimeNumberField(
          value: _dpi,
          step: 10,
          min: 36,
          max: 600,
          precision: 0,
          onChanged: (v) {
            if (v != null) setState(() => _dpi = v);
          },
        ),
        const SizedBox(height: 10),
        _label('Output size (locked to canvas aspect)'),
        Text(
          '$_outW × $_outH px  (canvas ${widget.canvasSize.width.round()}×${widget.canvasSize.height.round()} @ ${_dpi.round()} DPI)',
          style: TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        _label('Background'),
        PrimeSelect<CanvasExportBackground>(
          value: _figBg,
          options: const {
            CanvasExportBackground.theme: 'Match theme',
            CanvasExportBackground.white: 'White',
            CanvasExportBackground.transparent: 'Transparent',
          },
          onChanged: (v) => setState(() => _figBg = v),
        ),
        const SizedBox(height: 10),
        _label('File name'),
        _nameField(_figName, 'png'),
        const SizedBox(height: 14),
        _exportButton('Export PNG', _exportFigure),
      ],
    );
  }

  Future<void> _exportFigure() async {
    setState(() => _busy = true);
    try {
      final bytes = await captureCanvasPng(
        pixelRatio: _dpi / 96.0,
        background: _figBg,
      );
      if (!mounted) return;
      if (bytes == null) {
        _snack(context, 'Export failed: could not render canvas',
            error: true);
        return;
      }
      var name = _figName.text.trim();
      if (name.isEmpty) name = 'figure';
      if (!name.toLowerCase().endsWith('.png')) name = '$name.png';
      final loc = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PNG image', extensions: ['png'])
        ],
      );
      final path = loc?.path;
      if (path == null || path.isEmpty) return;
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _snack(context, 'Exported $_outW×$_outH @ ${_dpi.round()} DPI');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Export failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ Data

  Widget _dataTab() {
    final targets = <String, String>{
      'combined': 'All datasets — combined file',
      for (final d in widget.datasets) d.id: d.name,
    };
    if (!targets.containsKey(_dataTarget)) _dataTarget = 'combined';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.graphId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'No active graph — select a graph first.',
              style: TextStyle(
                  fontSize: 12, color: PrimeTheme.textSecondary),
            ),
          ),
        _label('Dataset'),
        PrimeSelect<String>(
          value: _dataTarget,
          options: targets,
          onChanged: (v) => setState(() {
            _dataTarget = v;
            final base = v == 'combined'
                ? '${widget.graphName}_all'
                : (targets[v] ?? widget.graphName);
            _dataName.text = base;
          }),
        ),
        const SizedBox(height: 10),
        _label('Format'),
        PrimeSelect<String>(
          value: _dataFormat,
          options: const {'csv': 'CSV (comma)', 'tsv': 'TSV (tab)'},
          onChanged: (v) => setState(() => _dataFormat = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text('Include header row',
                  style: TextStyle(
                      fontSize: 12, color: PrimeTheme.textPrimary)),
            ),
            PrimeSwitch(
              value: _includeHeader,
              onChanged: (v) => setState(() => _includeHeader = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _label('File name'),
        _nameField(_dataName, _dataFormat),
        const SizedBox(height: 14),
        _exportButton('Export Data', _exportData),
      ],
    );
  }

  Future<void> _exportData() async {
    final graphId = widget.graphId;
    if (graphId == null) {
      _snack(context, 'Export failed: no active graph', error: true);
      return;
    }
    final delim = _dataFormat == 'tsv' ? '\t' : ',';
    var name = _dataName.text.trim();
    if (name.isEmpty) name = 'data';
    if (!name.toLowerCase().endsWith('.$_dataFormat')) {
      name = '$name.$_dataFormat';
    }
    final loc = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(
            label: _dataFormat.toUpperCase(),
            extensions: [_dataFormat])
      ],
    );
    final path = loc?.path;
    if (path == null || path.isEmpty) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (_dataTarget == 'combined') {
        xp.exportGraphDataCsv(
          graphId: graphId,
          path: path,
          delimiter: delim,
          includeHeader: _includeHeader,
        );
      } else {
        xp.exportTableCsv(
          tableId: _dataTarget,
          path: path,
          delimiter: delim,
          includeHeader: _includeHeader,
        );
      }
      if (mounted) {
        _snack(context, 'Exported $name');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      _snack(context,
          'Export failed: ${e.toString().replaceFirst('Exception: ', '')}',
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- shared

  Widget _nameField(TextEditingController controller, String extHint) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        suffixText: '.$extHint',
        suffixStyle:
            TextStyle(fontSize: 11, color: PrimeTheme.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: PrimeTheme.searchBarBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: PrimeTheme.borderSide),
        ),
      ),
    );
  }

  Widget _exportButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: PrimeTheme.primaryAccent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _DisabledRow extends StatelessWidget {
  final String label;
  final String note;
  const _DisabledRow({required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: PrimeTheme.searchBarBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: PrimeTheme.borderSide),
      ),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PrimeTheme.textPrimary)),
          const Spacer(),
          Text(note,
              style: TextStyle(
                  fontSize: 11, color: PrimeTheme.textSecondary)),
        ],
      ),
    );
  }
}
