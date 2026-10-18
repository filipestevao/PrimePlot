// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/file_actions.dart';
import '../../core/state.dart';
import '../../core/theme.dart';
import '../../src/rust/api/project.dart';
import '../dialogs/export_dialog.dart';
import '../dialogs/settings_dialog.dart';

/// One row in the search results overlay.
class _SearchEntry {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? hint;
  final VoidCallback onActivate;

  _SearchEntry({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.hint,
    required this.onActivate,
  });
}

/// Centered command palette: live search across project tree nodes
/// (graphs, datasets, functions, folders, shapes) and common application
/// commands. Ctrl+F focuses it from anywhere.
class PrimeSearchBar extends StatefulWidget {
  const PrimeSearchBar({super.key});

  static final ValueNotifier<int> _focusRequests = ValueNotifier<int>(0);

  /// Asks the search field to take focus and select its text (Ctrl+F).
  /// Counter-based so any layer can trigger it without a GlobalKey.
  static void requestFocus() => _focusRequests.value++;

  @override
  State<PrimeSearchBar> createState() => _PrimeSearchBarState();
}

class _PrimeSearchBarState extends State<PrimeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _link = LayerLink();
  final Object _tapRegionGroup = Object();

  OverlayEntry? _entry;
  List<_SearchEntry> _nodes = const [];
  List<_SearchEntry> _commands = const [];
  int _highlighted = 0;
  int _blurToken = 0;

  /// Result caps keep the card within its 320px max height.
  static const int _maxNodes = 6;
  static const int _maxCommands = 4;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _focusNode.addListener(_onFocusChanged);
    PrimeSearchBar._focusRequests.addListener(_onFocusRequested);
  }

  @override
  void dispose() {
    PrimeSearchBar._focusRequests.removeListener(_onFocusRequested);
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusRequested() {
    if (!mounted) return;
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_controller.text.trim().isNotEmpty) _refreshOverlay();
    } else {
      // Deferred so a tap on an overlay row (same TapRegion group) can
      // complete before the card is torn down.
      final token = ++_blurToken;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted || token != _blurToken || _focusNode.hasFocus) return;
        _removeOverlay();
      });
    }
  }

  void _onQueryChanged() {
    _recomputeResults();
    _refreshOverlay();
  }

  // -------------------------------------------------------------------------
  // Search
  // -------------------------------------------------------------------------

  void _recomputeResults() {
    final query = _controller.text.trim().toLowerCase();
    _highlighted = 0;
    if (query.isEmpty) {
      _nodes = const [];
      _commands = const [];
      return;
    }

    final nodes = <_SearchEntry>[];
    final root = ProjectState.instance.projectTree.value;
    if (root != null) {
      void visit(ProjectNode node) {
        if (nodes.length >= _maxNodes) return;
        if (node.name.toLowerCase().contains(query)) {
          nodes.add(_nodeEntry(node));
        }
        for (final child in node.children) {
          visit(child);
        }
      }

      for (final child in root.children) {
        visit(child);
        if (nodes.length >= _maxNodes) break;
      }
    }

    _nodes = nodes;
    _commands = _commandEntries()
        .where((c) => c.label.toLowerCase().contains(query))
        .take(_maxCommands)
        .toList();
  }

  _SearchEntry _nodeEntry(ProjectNode node) {
    final (icon, color) = switch (node.nodeType) {
      NodeType.folder => (Icons.folder_outlined, PrimeTheme.textSecondary),
      NodeType.plot => (Icons.show_chart, PrimeTheme.primaryAccent),
      NodeType.dataset => (Icons.table_chart, PrimeTheme.textPrimary),
      NodeType.function => (Icons.functions, Colors.purpleAccent),
      NodeType.shape => (Icons.category, Colors.orangeAccent),
    };
    return _SearchEntry(
      icon: icon,
      iconColor: color,
      label: node.name,
      onActivate: () => ProjectState.instance.selectProjectNode(node.id),
    );
  }

  List<_SearchEntry> _commandEntries() {
    final st = ProjectState.instance;
    return [
      _SearchEntry(
        icon: Icons.note_add_outlined,
        iconColor: PrimeTheme.textSecondary,
        label: 'New Project',
        hint: 'Ctrl + N',
        onActivate: () => FileActions.doNew(context),
      ),
      _SearchEntry(
        icon: Icons.folder_open,
        iconColor: PrimeTheme.textSecondary,
        label: 'Open Project…',
        hint: 'Ctrl + O',
        onActivate: () => FileActions.doOpen(context),
      ),
      _SearchEntry(
        icon: Icons.save_outlined,
        iconColor: PrimeTheme.textSecondary,
        label: 'Save Project',
        hint: 'Ctrl + S',
        onActivate: () => FileActions.doSave(context),
      ),
      _SearchEntry(
        icon: Icons.save_as_outlined,
        iconColor: PrimeTheme.textSecondary,
        label: 'Save Project As…',
        hint: 'Ctrl + Shift + S',
        onActivate: () => FileActions.doSaveAs(context),
      ),
      _SearchEntry(
        icon: Icons.image_outlined,
        iconColor: PrimeTheme.textSecondary,
        label: 'Export Figure…',
        hint: 'Ctrl + E',
        onActivate: () => openExportDialog(context, 0),
      ),
      _SearchEntry(
        icon: Icons.table_view_outlined,
        iconColor: PrimeTheme.textSecondary,
        label: 'Export Data…',
        hint: 'Ctrl + Shift + E',
        onActivate: () => openExportDialog(context, 1),
      ),
      _SearchEntry(
        icon: Icons.table_chart,
        iconColor: PrimeTheme.textSecondary,
        label: 'Add Table',
        onActivate: _addTable,
      ),
      _SearchEntry(
        icon: Icons.functions,
        iconColor: PrimeTheme.textSecondary,
        label: 'Add Function',
        onActivate: () => st.newFunction(),
      ),
      _SearchEntry(
        icon: Icons.show_chart,
        iconColor: PrimeTheme.textSecondary,
        label: 'Add Graph',
        onActivate: () => st.newGraph(),
      ),
      _SearchEntry(
        icon: Icons.settings_outlined,
        iconColor: PrimeTheme.textSecondary,
        label: 'Settings…',
        onActivate: () => showDialog(
          context: context,
          builder: (_) => const SettingsDialog(),
        ),
      ),
    ];
  }

  void _addTable() {
    final st = ProjectState.instance;
    if (st.getValidParentGraphId() == null) st.newGraph();
    st.newTable();
  }

  // -------------------------------------------------------------------------
  // Results overlay
  // -------------------------------------------------------------------------

  void _refreshOverlay() {
    final visible = _focusNode.hasFocus &&
        _controller.text.trim().isNotEmpty &&
        (_nodes.isNotEmpty || _commands.isNotEmpty);
    if (!visible) {
      _removeOverlay();
      return;
    }
    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (_) => Positioned(
          width: 340,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: _buildResultsCard(),
          ),
        ),
      );
      Overlay.of(context).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  Widget _buildResultsCard() {
    final rows = <Widget>[];
    var index = 0;
    if (_nodes.isNotEmpty) {
      rows.add(_sectionHeader('PROJECT ITEMS'));
      for (final e in _nodes) {
        rows.add(_resultRow(index++, e));
      }
    }
    if (_commands.isNotEmpty) {
      rows.add(_sectionHeader('COMMANDS'));
      for (final e in _commands) {
        rows.add(_resultRow(index++, e));
      }
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: PrimeTheme.panelBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: PrimeTheme.borderSide),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: rows,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: PrimeTheme.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _resultRow(int index, _SearchEntry entry) {
    final active = index == _highlighted;
    return TapRegion(
      groupId: _tapRegionGroup,
      child: InkWell(
        onTap: () => _activate(entry),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: active
              ? PrimeTheme.primaryAccent.withValues(alpha: 0.14)
              : null,
          child: Row(
            children: [
              Icon(entry.icon, size: 14, color: entry.iconColor),
              const SizedBox(width: 8),
              Expanded(child: _highlightLabel(entry.label)),
              if (entry.hint != null)
                Text(
                  entry.hint!,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: PrimeTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlightLabel(String label) {
    final query = _controller.text.trim();
    final idx = query.isEmpty
        ? -1
        : label.toLowerCase().indexOf(query.toLowerCase());
    final base = TextStyle(fontSize: 12, color: PrimeTheme.textPrimary);
    if (idx < 0) {
      return Text(label,
          style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label.substring(0, idx)),
          TextSpan(
            text: label.substring(idx, idx + query.length),
            style: TextStyle(
              color: PrimeTheme.primaryAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: label.substring(idx + query.length)),
        ],
      ),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // -------------------------------------------------------------------------
  // Activation & keyboard
  // -------------------------------------------------------------------------

  void _activate(_SearchEntry entry) {
    _removeOverlay();
    _controller.clear();
    _focusNode.unfocus();
    entry.onActivate();
  }

  void _activateHighlighted() {
    if (_entry == null) return;
    final total = _nodes.length + _commands.length;
    if (total == 0) return;
    final index = _highlighted.clamp(0, total - 1);
    final entry =
        index < _nodes.length ? _nodes[index] : _commands[index - _nodes.length];
    _activate(entry);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _removeOverlay();
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }
    final total = _nodes.length + _commands.length;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (total == 0 || _entry == null) return KeyEventResult.ignored;
      _highlighted = (_highlighted + 1).clamp(0, total - 1);
      _entry!.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (total == 0 || _entry == null) return KeyEventResult.ignored;
      _highlighted = (_highlighted - 1).clamp(0, total - 1);
      _entry!.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activateHighlighted();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Focus(
        onKeyEvent: _onKeyEvent,
        child: ListenableBuilder(
          listenable: Listenable.merge([_focusNode, _controller]),
          builder: (context, _) {
            final focused = _focusNode.hasFocus;
            return Container(
              width: 320,
              height: 32,
              decoration: BoxDecoration(
                color: PrimeTheme.searchBarBackground,
                borderRadius: BorderRadius.circular(6.0),
                border: Border.all(
                  color: focused
                      ? PrimeTheme.primaryAccent.withValues(alpha: 0.6)
                      : PrimeTheme.borderSide,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    Icons.search,
                    size: 15,
                    color: focused
                        ? PrimeTheme.primaryAccent
                        : PrimeTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      groupId: _tapRegionGroup,
                      style: TextStyle(
                        fontSize: 12,
                        color: PrimeTheme.textPrimary,
                      ),
                      cursorColor: PrimeTheme.primaryAccent,
                      cursorHeight: 14,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search nodes or commands… (Ctrl + F)',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color:
                              PrimeTheme.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                      onSubmitted: (_) => _activateHighlighted(),
                      onTapOutside: (_) {
                        _removeOverlay();
                        _focusNode.unfocus();
                      },
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    InkWell(
                      onTap: () {
                        _controller.clear();
                        _focusNode.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(3),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: PrimeTheme.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

