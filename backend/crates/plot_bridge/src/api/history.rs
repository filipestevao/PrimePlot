// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Undo / redo history (Step G). Snapshot-based: every checkpoint clones
//! the full project state (tree, tables, all property maps) in memory.
//! Bounded (cap 50), session-only — never serialized into `.primeplot`.
//! Flutter calls `checkpoint()` *before* each mutation (debounced there);
//! undo/redo restore snapshots and never checkpoint themselves.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use data_engine::table::DataTable as EngineDataTable;
use data_engine::ProjectNode as EngineProjectNode;

use crate::api::properties::{
    FolderProperties, FunctionProperties, GraphProperties, ShapeProperties,
    TableProperties,
};
use crate::api::sync::lock_or_recover;

#[derive(Clone)]
struct HistorySnapshot {
    tree: EngineProjectNode,
    tables: HashMap<String, EngineDataTable>,
    folder_props: HashMap<String, FolderProperties>,
    graph_props: HashMap<String, GraphProperties>,
    table_props: HashMap<String, TableProperties>,
    function_props: HashMap<String, FunctionProperties>,
    shape_props: HashMap<String, ShapeProperties>,
}

/// Button/FRB status (both fields drive UI enablement).
#[derive(Clone, Debug)]
pub struct HistoryStatus {
    pub can_undo: bool,
    pub can_redo: bool,
}

const HISTORY_CAP: usize = 50;

static UNDO_STACK: OnceLock<Mutex<Vec<HistorySnapshot>>> = OnceLock::new();
static REDO_STACK: OnceLock<Mutex<Vec<HistorySnapshot>>> = OnceLock::new();

fn undo_stack() -> &'static Mutex<Vec<HistorySnapshot>> {
    UNDO_STACK.get_or_init(|| Mutex::new(Vec::new()))
}

fn redo_stack() -> &'static Mutex<Vec<HistorySnapshot>> {
    REDO_STACK.get_or_init(|| Mutex::new(Vec::new()))
}

fn snapshot_current() -> HistorySnapshot {
    HistorySnapshot {
        tree: crate::api::project::snapshot_tree_engine(),
        tables: crate::api::project::snapshot_tables_engine(),
        folder_props: crate::api::properties::snapshot_folder_props(),
        graph_props: crate::api::properties::snapshot_graph_props(),
        table_props: crate::api::properties::snapshot_table_props(),
        function_props: crate::api::properties::snapshot_function_props(),
        shape_props: crate::api::properties::snapshot_shape_props(),
    }
}

fn restore_snapshot(snap: &HistorySnapshot) {
    crate::api::project::restore_tree_engine(snap.tree.clone());
    crate::api::project::restore_tables_engine(snap.tables.clone());
    crate::api::properties::restore_folder_props(snap.folder_props.clone());
    crate::api::properties::restore_graph_props(snap.graph_props.clone());
    crate::api::properties::restore_table_props(snap.table_props.clone());
    crate::api::properties::restore_function_props(snap.function_props.clone());
    crate::api::properties::restore_shape_props(snap.shape_props.clone());
}

fn push_capped(stack: &Mutex<Vec<HistorySnapshot>>, snap: HistorySnapshot) {
    let mut guard = lock_or_recover(stack);
    guard.push(snap);
    while guard.len() > HISTORY_CAP {
        guard.remove(0);
    }
}

/// Records the pre-mutation state; clears the redo stack.
#[flutter_rust_bridge::frb(sync)]
pub fn checkpoint() {
    let snap = snapshot_current();
    push_capped(undo_stack(), snap);
    lock_or_recover(redo_stack()).clear();
}

/// Restores the last checkpoint (current state moves to redo).
#[flutter_rust_bridge::frb(sync)]
pub fn undo() -> Result<crate::api::project::ProjectNode, String> {
    let snap = lock_or_recover(undo_stack())
        .pop()
        .ok_or_else(|| "nothing to undo".to_string())?;
    push_capped(redo_stack(), snapshot_current());
    restore_snapshot(&snap);
    Ok(snap.tree.into())
}

/// Re-applies an undone state (current state moves back to undo).
#[flutter_rust_bridge::frb(sync)]
pub fn redo() -> Result<crate::api::project::ProjectNode, String> {
    let snap = lock_or_recover(redo_stack())
        .pop()
        .ok_or_else(|| "nothing to redo".to_string())?;
    push_capped(undo_stack(), snapshot_current());
    restore_snapshot(&snap);
    Ok(snap.tree.into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn history_status() -> HistoryStatus {
    HistoryStatus {
        can_undo: !lock_or_recover(undo_stack()).is_empty(),
        can_redo: !lock_or_recover(redo_stack()).is_empty(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn clear_stacks() {
        lock_or_recover(undo_stack()).clear();
        lock_or_recover(redo_stack()).clear();
    }

    #[test]
    fn undo_redo_round_trip() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved_tree = crate::api::project::snapshot_tree_engine();
        let saved_tables = crate::api::project::snapshot_tables_engine();
        let saved_graph = crate::api::properties::snapshot_graph_props();
        clear_stacks();

        assert!(undo().is_err());
        assert!(redo().is_err());

        checkpoint();
        crate::api::project::restore_tables_engine(HashMap::new());
        let tree = undo().unwrap();
        assert!(!tree.id.is_empty());
        // Tables restored to the checkpoint (whatever the session held).
        assert!(redo().is_ok());

        let status = history_status();
        assert!(status.can_undo);
        assert!(!status.can_redo);

        crate::api::project::restore_tree_engine(saved_tree);
        crate::api::project::restore_tables_engine(saved_tables);
        crate::api::properties::restore_graph_props(saved_graph);
        clear_stacks();
    }

    #[test]
    fn cap_evicts_oldest() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        clear_stacks();
        for _ in 0..(HISTORY_CAP + 5) {
            checkpoint();
        }
        assert_eq!(lock_or_recover(undo_stack()).len(), HISTORY_CAP);
        // Redo cleared by checkpointing.
        assert!(!history_status().can_redo);
        clear_stacks();
    }
}
