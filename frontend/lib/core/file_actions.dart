// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! File-level actions for `.primeplot` bundles: New / Open / Save / Save As.
//!
//! UI layer owns dialogs + native pickers; Rust remains SSOT for state.
//! [ProjectState] owns path + dirty flag; these helpers only orchestrate.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'state.dart';

/// Result of the unsaved-changes prompt.
enum _DiscardChoice { save, discard, cancel }

class FileActions {
  static const _ext = 'primeplot';
  static const _typeGroup = XTypeGroup(
    label: 'PrimePlot project',
    extensions: [_ext],
  );
  static const _dataTypeGroup = XTypeGroup(
    label: 'Data files',
    extensions: ['csv', 'tsv', 'txt'],
  );

  static String ensureExtension(String path) {
    if (path.toLowerCase().endsWith('.$_ext')) return path;
    return '$path.$_ext';
  }

  static void _snack(BuildContext context, String message, {bool error = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: error ? const Color(0xFF7F1D1D) : const Color(0xFF1C2331),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 5 : 2),
      ),
    );
  }

  /// Public entry for the unsaved-changes prompt (Save / Discard / Cancel).
  /// Returns true when the caller may proceed with the destructive action.
  static Future<bool> confirmUnsavedChanges(
    BuildContext context,
    String actionName,
  ) =>
      _confirmDiscardIfDirty(context, actionName);

  /// Prompts Save / Discard / Cancel when dirty. Returns true if caller
  /// may proceed (saved or discarded), false on cancel / failed save.
  static Future<bool> _confirmDiscardIfDirty(
    BuildContext context,
    String actionName,
  ) async {
    final st = ProjectState.instance;
    if (!st.isDirty.value) return true;
    final choice = await showDialog<_DiscardChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: Text(
          'Save changes to ${st.displayFileName} before $actionName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DiscardChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DiscardChoice.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _DiscardChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (choice == null || choice == _DiscardChoice.cancel) return false;
    if (choice == _DiscardChoice.discard) return true;
    // Save then proceed only if the save actually succeeded.
    if (!context.mounted) return false;
    return await doSave(context);
  }

  /// Saves to the current path, falling back to Save As when untitled.
  /// Returns true on success.
  static Future<bool> doSave(BuildContext context) async {
    final st = ProjectState.instance;
    final current = st.currentFilePath.value;
    if (current == null || current.isEmpty) return doSaveAs(context);
    final err = st.saveToCurrentPath();
    if (err != null) {
      _snack(context, 'Save failed: $err', error: true);
      return false;
    }
    _snack(context, 'Saved ${st.displayFileName}');
    return true;
  }

  static Future<bool> doSaveAs(BuildContext context) async {
    final st = ProjectState.instance;
    final suggested = st.displayFileName.endsWith('.$_ext')
        ? st.displayFileName
        : '${st.displayFileName}.$_ext';
    // Native save dialog; Rust writes the bundle to the chosen path.
    final location = await getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: [_typeGroup],
    );
    final picked = location?.path;
    if (picked == null || picked.isEmpty) return false; // user cancelled
    final path = ensureExtension(picked);
    final err = st.saveToPath(path);
    if (!context.mounted) return err == null;
    if (err != null) {
      _snack(context, 'Save failed: $err', error: true);
      return false;
    }
    _snack(context, 'Saved ${st.displayFileName}');
    return true;
  }

  static Future<void> doOpen(BuildContext context) async {
    if (!await _confirmDiscardIfDirty(context, 'opening')) return;
    if (!context.mounted) return;
    final file = await openFile(acceptedTypeGroups: [_typeGroup]);
    if (!context.mounted) return;
    final path = file?.path;
    if (path == null || path.isEmpty) return; // user cancelled
    final st = ProjectState.instance;
    final err = st.openFromPath(path);
    if (err != null) {
      _snack(context, 'Open failed: $err', error: true);
      return;
    }
    _snack(context, 'Opened ${st.displayFileName}');
  }

  static Future<void> doNew(BuildContext context) async {
    if (!await _confirmDiscardIfDirty(context, 'creating a new project')) {
      return;
    }
    if (!context.mounted) return;
    ProjectState.instance.createNew();
    _snack(context, 'New project created');
  }

  /// Drawer entry point: multi-select data files and import them as tables
  /// under the active graph (mouse-only equivalent of drag & drop).
  static Future<void> doImportData(BuildContext context) async {
    final files = await openFiles(acceptedTypeGroups: [_dataTypeGroup]);
    if (!context.mounted) return;
    await importDataFiles(context, files);
  }

  /// Reads and imports data files as separate tables under the active graph:
  /// one undo step for the whole batch, one summary snackbar — failures are
  /// listed, never silent.
  static Future<void> importDataFiles(
    BuildContext context,
    List<XFile> files,
  ) async {
    if (files.isEmpty) return;
    final contents = <({String raw, String name})>[];
    final failed = <String>[];
    for (final f in files) {
      try {
        contents.add((raw: await f.readAsString(), name: f.name));
      } catch (_) {
        failed.add(f.name);
      }
    }
    var imported = 0;
    if (contents.isNotEmpty) {
      final result = ProjectState.instance.handleDataImports(contents);
      imported = result.imported;
      failed.addAll(result.failed);
    }
    final noun = imported == 1 ? 'table' : 'tables';
    if (!context.mounted) return;
    if (failed.isEmpty) {
      _snack(context, 'Imported $imported $noun');
    } else {
      _snack(
        context,
        'Imported $imported $noun, ${failed.length} failed: '
        '${failed.join(', ')}',
        error: true,
      );
    }
  }
}
