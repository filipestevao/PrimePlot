// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Transform dock panel + shared form: quick ops, scalar add/multiply,
//! custom `y`/`i` expressions with live preview, linspace fill, and live
//! statistics. Preview never mutates; Apply commits through `ProjectState`
//! (dirty + repaint).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/transforms.dart' as tr;
import '../components/panel_container.dart';
import '../components/prime_number_field.dart';

/// Docked panel below the Property Inspector. Follows
/// `ProjectState.selectedColumn` with a live table lookup, so renames and
/// structural edits resolve (or hide the panel) gracefully.
class TransformPanel extends StatelessWidget {
  const TransformPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final st = ProjectState.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([st.selectedColumn, st.activeTable]),
      builder: (context, _) {
        final sel = st.selectedColumn.value;
        final table = st.activeTable.value;
        if (sel == null ||
            table == null ||
            table.id != sel.tableId ||
            sel.colIndex < 0 ||
            sel.colIndex >= table.columns.length) {
          return const SizedBox.shrink();
        }
        final col = table.columns[sel.colIndex];
        final rows = table.columns
            .map((c) => c.data.length)
            .fold(0, (a, b) => math.max(a, b));
        return PanelContainer(
          title: 'Transform',
          icon: Icons.calculate,
          actions: [
            Tooltip(
              message: 'Close transform panel',
              child: InkWell(
                onTap: st.clearSelectedColumn,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      size: 15, color: PrimeTheme.textSecondary),
                ),
              ),
            ),
          ],
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: ColumnTransformForm(
              key: ValueKey('${table.id}:${sel.colIndex}'),
              tableId: table.id,
              colIndex: sel.colIndex,
              colName: col.name,
              rowCount: rows,
            ),
          ),
        );
      },
    );
  }
}

class ColumnTransformForm extends StatefulWidget {
  final String tableId;
  final int colIndex;
  final String colName;
  final int rowCount;

  const ColumnTransformForm({
    super.key,
    required this.tableId,
    required this.colIndex,
    required this.colName,
    required this.rowCount,
  });

  @override
  State<ColumnTransformForm> createState() => _ColumnTransformFormState();
}

class _ColumnTransformFormState extends State<ColumnTransformForm> {
  final TextEditingController _exprController =
      TextEditingController(text: 'y');
  double _scalar = 1.0;
  double _linStart = 0.0;
  double _linEnd = 1.0;

  tr.ColumnStatistics? _stats;
  List<double>? _preview;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _reloadStats();
    _reloadPreview();
  }

  @override
  void dispose() {
    _exprController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
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

  void _reloadStats() {
    try {
      final s = tr.getColumnStatistics(
        tableId: widget.tableId,
        colIndex: BigInt.from(widget.colIndex),
      );
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      if (mounted) setState(() => _stats = null);
    }
  }

  void _reloadPreview() {
    try {
      final p = tr.previewColumnExpression(
        tableId: widget.tableId,
        colIndex: BigInt.from(widget.colIndex),
        expr: _exprController.text,
      );
      if (mounted) {
        setState(() {
          _preview = p.toList();
          _previewError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _preview = null;
          _previewError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _commit(String? err, String what) {
    if (err != null) {
      _snack('$what failed: $err', error: true);
      return;
    }
    _reloadStats();
    _reloadPreview();
  }

  @override
  Widget build(BuildContext context) {
    final st = ProjectState.instance;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.colName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PrimeTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
              _sectionLabel('Quick operations'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _quick('× −1', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, 'y * -1'),
                      'Negate')),
                  _quick('ln(y)', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, 'ln(y)'),
                      'ln')),
                  _quick('log₁₀(y)', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, 'log10(y)'),
                      'log10')),
                  _quick('eʸ', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, 'exp(y)'),
                      'exp')),
                  _quick('y²', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, 'y^2'),
                      'Square')),
                  _quick('√y', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, 'sqrt(y)'),
                      'sqrt')),
                  _quick('1/y', () => _commit(
                      st.applyColumnExpression(
                          widget.tableId, widget.colIndex, '1/y'),
                      'Invert')),
                  _quick('Normalize', () => _commit(
                      st.normalizeColumn(widget.tableId, widget.colIndex),
                      'Normalize')),
                ],
              ),
              const SizedBox(height: 12),
              _sectionLabel('Scalar (applies to every cell)'),
              Row(
                children: [
                  Expanded(
                    child: PrimeNumberField(
                      value: _scalar,
                      step: 1.0,
                      precision: 3,
                      onChanged: (v) {
                        if (v != null) setState(() => _scalar = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  _action('+ Add', () => _commit(
                      st.addScalarToColumn(
                          widget.tableId, widget.colIndex, _scalar),
                      'Add scalar')),
                  const SizedBox(width: 6),
                  _action('× Mul', () => _commit(
                      st.multiplyColumn(
                          widget.tableId, widget.colIndex, _scalar),
                      'Multiply')),
                ],
              ),
              const SizedBox(height: 12),
              _sectionLabel('Custom expression (y = cell, i = row index)'),
              TextField(
                controller: _exprController,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: PrimeTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: PrimeTheme.searchBarBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: _previewError != null
                          ? const Color(0xFFF87171)
                          : PrimeTheme.borderSide,
                    ),
                  ),
                ),
                onChanged: (_) => _reloadPreview(),
              ),
              const SizedBox(height: 4),
              if (_previewError != null)
                Text(
                  _previewError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFF87171),
                  ),
                )
              else if (_preview != null)
                Text(
                  '→ ${_preview!.map(_fmt).join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: PrimeTheme.textSecondary,
                  ),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: _action('Apply expression', () => _commit(
                    st.applyColumnExpression(widget.tableId, widget.colIndex,
                        _exprController.text),
                    'Expression')),
              ),
              const SizedBox(height: 12),
              _sectionLabel(
                  'Fill linspace (${widget.rowCount} rows)'),
              Row(
                children: [
                  Expanded(
                    child: PrimeNumberField(
                      value: _linStart,
                      prefixText: 'From: ',
                      step: 1.0,
                      precision: 3,
                      onChanged: (v) {
                        if (v != null) setState(() => _linStart = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: PrimeNumberField(
                      value: _linEnd,
                      prefixText: 'To: ',
                      step: 1.0,
                      precision: 3,
                      onChanged: (v) {
                        if (v != null) setState(() => _linEnd = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  _action('Fill', () => _commit(
                      st.fillColumnLinspace(widget.tableId, widget.colIndex,
                          _linStart, _linEnd),
                      'Linspace')),
                ],
              ),
              const SizedBox(height: 12),
              _sectionLabel('Statistics'),
              _statsRow(),
            ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: PrimeTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _quick(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: PrimeTheme.searchBarBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: PrimeTheme.borderSide),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: PrimeTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _action(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: PrimeTheme.primaryAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: PrimeTheme.primaryAccent.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PrimeTheme.primaryAccent,
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v.isNaN) return '—';
    final a = v.abs();
    if (a != 0 && (a >= 100000 || a < 0.001)) {
      return v.toStringAsExponential(1);
    }
    return v.toStringAsFixed(3);
  }

  Widget _statsRow() {
    final s = _stats;
    if (s == null) {
      return Text('No statistics available.',
          style: TextStyle(fontSize: 11, color: PrimeTheme.textSecondary));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: PrimeTheme.searchBarBackground,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: PrimeTheme.borderSide),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('min', _fmt(s.min)),
          _stat('max', _fmt(s.max)),
          _stat('mean', _fmt(s.mean)),
          _stat('σ', _fmt(s.stdDev)),
          _stat('n', '${s.count}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: PrimeTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: PrimeTheme.textPrimary,
            )),
      ],
    );
  }
}
