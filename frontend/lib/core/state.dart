import 'package:flutter/foundation.dart';
import '../src/rust/api/data.dart';

/// A lightweight, globally accessible state manager.
class ProjectState {
  static final ProjectState instance = ProjectState._internal();
  ProjectState._internal();

  /// Holds the active DataTable. Both the Table UI and the Canvas listen to this.
  final ValueNotifier<DTODataTable?> activeTable = ValueNotifier(null);
  
  /// Controls whether the table cells are currently editable.
  final ValueNotifier<bool> isTableEditable = ValueNotifier(true);

  // Panel titles
  final ValueNotifier<String> tableName = ValueNotifier('Table');
  final ValueNotifier<String> graphName = ValueNotifier('Graph');
  
  // Panel visibility
  final ValueNotifier<bool> isTableVisible = ValueNotifier(true);
  final ValueNotifier<bool> isGraphVisible = ValueNotifier(true);

  void loadInitialData() {
    activeTable.value = getInitialTableData();
  }

  void updateTable(DTODataTable newTable) {
    activeTable.value = newTable;
  }

  void toggleTableEditMode() {
    isTableEditable.value = !isTableEditable.value;
  }
}
