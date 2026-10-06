// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

use data_engine::{NodeType as EngineNodeType, ProjectNode as EngineProjectNode};

#[derive(Clone, Debug)]
pub enum NodeType {
    Folder,
    Dataset,
    Plot,
    Function,
    Shape,
}

#[derive(Clone, Debug)]
pub struct ProjectNode {
    pub id: String,
    pub name: String,
    pub node_type: NodeType,
    pub children: Vec<ProjectNode>,
}

impl From<EngineNodeType> for NodeType {
    fn from(engine_node_type: EngineNodeType) -> Self {
        match engine_node_type {
            EngineNodeType::Folder => NodeType::Folder,
            EngineNodeType::Dataset => NodeType::Dataset,
            EngineNodeType::Plot => NodeType::Plot,
            EngineNodeType::Function => NodeType::Function,
            EngineNodeType::Shape => NodeType::Shape,
        }
    }
}

impl From<EngineProjectNode> for ProjectNode {
    fn from(engine_node: EngineProjectNode) -> Self {
        ProjectNode {
            id: engine_node.id,
            name: engine_node.name,
            node_type: engine_node.node_type.into(),
            children: engine_node.children.into_iter().map(|c| c.into()).collect(),
        }
    }
}

use std::sync::{Mutex, MutexGuard, OnceLock};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::collections::HashMap;
use crate::api::sync::lock_or_recover;
use data_engine::table::{DataTable as EngineDataTable, DataColumn as EngineDataColumn, ColumnRole as EngineColumnRole};
use crate::api::data::{DTODataTable, DTOColumnRole};

static PROJECT_STATE: OnceLock<Mutex<EngineProjectNode>> = OnceLock::new();
static NEXT_ID: AtomicUsize = AtomicUsize::new(100);

pub(crate) fn get_state() -> &'static Mutex<EngineProjectNode> {
    PROJECT_STATE.get_or_init(|| {
        let mut root = EngineProjectNode::new("root_1", "Workspace", EngineNodeType::Folder);
        let mut project = EngineProjectNode::new("project_1", "Project", EngineNodeType::Folder);
        let mut graph = EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
        graph.add_child(EngineProjectNode::new("table_1", "Table", EngineNodeType::Dataset));
        project.add_child(graph);
        root.add_child(project);

        // Also seed TABLE_STORE with the initial empty table so get_table / update_table_from_raw work.
        let initial = crate::api::data::get_empty_table_data();
        let mut store = lock_or_recover(TABLE_STORE.get_or_init(|| Mutex::new(HashMap::new())));
        store.insert(initial.id.clone(), dto_to_engine_table(initial));

        Mutex::new(root)
    })
}

fn generate_id(prefix: &str) -> String {
    let id = NEXT_ID.fetch_add(1, Ordering::SeqCst);
    format!("{}_{}", prefix, id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_project_tree() -> ProjectNode {
    let state = lock_or_recover(get_state());
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn add_project_node(parent_id: String, name: String, node_type: NodeType) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    
    let engine_type = match node_type {
        NodeType::Folder => EngineNodeType::Folder,
        NodeType::Dataset => EngineNodeType::Dataset,
        NodeType::Plot => EngineNodeType::Plot,
        NodeType::Function => EngineNodeType::Function,
        NodeType::Shape => EngineNodeType::Shape,
    };
    
    let prefix = match node_type {
        NodeType::Folder => "folder",
        NodeType::Dataset => "table",
        NodeType::Plot => "graph",
        NodeType::Function => "function",
        NodeType::Shape => "shape",
    };
    
    let new_id = generate_id(prefix);
    let new_node = EngineProjectNode::new(&new_id, &name, engine_type);
    let mut opt_node = Some(new_node);
    
    // Attempt to insert into specified parent.
    state.insert_node_opt(&parent_id, &mut opt_node);
    
    // If we failed to insert (parent not found or it's root but handled), append to root.
    if let Some(node) = opt_node.take() {
        state.add_child(node);
    }

    // Seed TABLE_STORE with an empty table for new Dataset nodes.
    if let NodeType::Dataset = node_type {
        let mut table = EngineDataTable::new(&new_id, &name);
        table.add_column(EngineDataColumn {
            name: "Col 1".to_string(),
            role: EngineColumnRole::X,
            data: Vec::new(),
        });
        table.add_column(EngineDataColumn {
            name: "Col 2".to_string(),
            role: EngineColumnRole::Y,
            data: Vec::new(),
        });
        let mut store = lock_or_recover(get_table_store());
        store.insert(new_id.clone(), table);
        drop(store);
        // Display Name follows the node name; palette color skips colors
        // already used by dataset + function siblings under the graph.
        let ds = dataset_ids_in_order(&state, &parent_id);
        let fs = function_ids_in_order(&state, &parent_id);
        let color =
            crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
        crate::api::palettes::init_curve_props(&new_id, &name, color);
    }

    // Newborn functions join the same palette cycle as datasets.
    if let NodeType::Function = node_type {
        let ds = dataset_ids_in_order(&state, &parent_id);
        let fs = function_ids_in_order(&state, &parent_id);
        let color =
            crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
        crate::api::palettes::init_function_props(&new_id, &name, color);
    }
    
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn move_project_node(node_id: String, new_parent_id: String) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    
    if node_id == "root_1" {
        return state.clone().into();
    }
    
    if let Some(node) = state.remove_node(&node_id) {
        let mut opt_node = Some(node);
        state.insert_node_opt(&new_parent_id, &mut opt_node);
        // If parent not found, put it back to root
        if let Some(node) = opt_node.take() {
            state.add_child(node);
        }
    }
    
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn rename_project_node(node_id: String, new_name: String) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    state.rename_node(&node_id, &new_name);
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn reorder_project_children(parent_id: String, old_index: usize, new_index: usize) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    state.reorder_children(&parent_id, old_index, new_index);
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn delete_project_node(node_id: String) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    
    if let Some(removed_node) = state.remove_node(&node_id) {
        let mut datasets_to_remove = Vec::new();
        
        // Recursive collector to find all dataset IDs in the removed subtree
        fn collect_datasets(n: &EngineProjectNode, datasets: &mut Vec<String>) {
            if let EngineNodeType::Dataset = n.node_type {
                datasets.push(n.id.clone());
            }
            for child in &n.children {
                collect_datasets(child, datasets);
            }
        }
        collect_datasets(&removed_node, &mut datasets_to_remove);
        
        let mut store = lock_or_recover(get_table_store());
        for id in datasets_to_remove {
            store.remove(&id);
        }
    }
    
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_table_from_raw(table_id: String, raw: String) {
    let mut new_dto = crate::api::data::parse_clipboard_table(raw);
    
    let mut store = lock_or_recover(get_table_store());
    if let Some(existing_table) = store.get_mut(&table_id) {
        new_dto.name = existing_table.name.clone();
    }
    new_dto.id = table_id.clone();
    store.insert(table_id, dto_to_engine_table(new_dto));
}

static TABLE_STORE: OnceLock<Mutex<HashMap<String, EngineDataTable>>> = OnceLock::new();

fn get_table_store() -> &'static Mutex<HashMap<String, EngineDataTable>> {
    TABLE_STORE.get_or_init(|| Mutex::new(HashMap::new()))
}

/// Crate-internal store access for table-mutating modules (transforms, …).
/// Callers must not hold `PROJECT_STATE` while locking (lock ordering).
pub(crate) fn lock_table_store() -> MutexGuard<'static, HashMap<String, EngineDataTable>> {
    lock_or_recover(get_table_store())
}

pub(crate) fn dto_to_engine_table(dto: DTODataTable) -> EngineDataTable {
    let mut et = EngineDataTable::new(&dto.id, &dto.name);
    for col in dto.columns {
        let role = match col.role {
            DTOColumnRole::X => EngineColumnRole::X,
            DTOColumnRole::Y => EngineColumnRole::Y,
            DTOColumnRole::XError => EngineColumnRole::XError,
            DTOColumnRole::YError => EngineColumnRole::YError,
            DTOColumnRole::Text => EngineColumnRole::Text,
        };
        et.add_column(EngineDataColumn { name: col.name, role, data: col.data });
    }
    et
}

#[flutter_rust_bridge::frb(sync)]
pub fn save_table(table_id: String, columns: Vec<crate::api::data::DTODataColumn>) {
    let mut store = lock_or_recover(get_table_store());
    let name = store.get(&table_id).map(|t| t.name.clone()).unwrap_or_default();
    let mut et = EngineDataTable::new(&table_id, &name);
    for col in columns {
        let role = match col.role {
            DTOColumnRole::X => EngineColumnRole::X,
            DTOColumnRole::Y => EngineColumnRole::Y,
            DTOColumnRole::XError => EngineColumnRole::XError,
            DTOColumnRole::YError => EngineColumnRole::YError,
            DTOColumnRole::Text => EngineColumnRole::Text,
        };
        et.add_column(EngineDataColumn { name: col.name, role, data: col.data });
    }
    store.insert(table_id, et);
}

// ---------------------------------------------------------------------------
// Column management (Step B): structural edits on one dataset.
// Each endpoint returns the updated table DTO or a clean error string.
// ---------------------------------------------------------------------------

fn parse_engine_role(role: &str) -> Result<EngineColumnRole, String> {
    match role.trim().to_ascii_lowercase().as_str() {
        "x" => Ok(EngineColumnRole::X),
        "y" => Ok(EngineColumnRole::Y),
        "xerror" | "x_error" => Ok(EngineColumnRole::XError),
        "yerror" | "y_error" => Ok(EngineColumnRole::YError),
        "text" => Ok(EngineColumnRole::Text),
        other => Err(format!(
            "unknown column role '{other}' (expected X, Y, XError, YError or Text)"
        )),
    }
}

fn table_not_found(table_id: &str) -> String {
    format!("table '{table_id}' not found")
}

/// Appends a blank column (NaN-filled to the current row count).
#[flutter_rust_bridge::frb(sync)]
pub fn add_column(
    table_id: String,
    name: String,
    role: String,
) -> Result<crate::api::data::DTODataTable, String> {
    let role = parse_engine_role(&role)?;
    let clean = name.trim();
    if clean.is_empty() {
        return Err("column name must not be empty".to_string());
    }
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    let rows = table.row_count();
    table.add_column(EngineDataColumn {
        name: clean.to_string(),
        role,
        data: vec![f64::NAN; rows],
    });
    Ok(table.clone().into())
}

/// Removes a column; refuses the last X or Y column.
#[flutter_rust_bridge::frb(sync)]
pub fn remove_column(
    table_id: String,
    col_index: usize,
) -> Result<crate::api::data::DTODataTable, String> {
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    table.remove_column(col_index)?;
    Ok(table.clone().into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn rename_column(
    table_id: String,
    col_index: usize,
    new_name: String,
) -> Result<crate::api::data::DTODataTable, String> {
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    table.rename_column(col_index, &new_name)?;
    Ok(table.clone().into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_column_role(
    table_id: String,
    col_index: usize,
    role: String,
) -> Result<crate::api::data::DTODataTable, String> {
    let role = parse_engine_role(&role)?;
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    table.set_column_role(col_index, role)?;
    Ok(table.clone().into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn reorder_column(
    table_id: String,
    old_index: usize,
    new_index: usize,
) -> Result<crate::api::data::DTODataTable, String> {
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    table.move_column(old_index, new_index)?;
    Ok(table.clone().into())
}

/// Appends `count` blank columns (NaN-filled to the current row count).
/// Names continue the `Col N` sequence.
#[flutter_rust_bridge::frb(sync)]
pub fn add_columns(
    table_id: String,
    count: usize,
    role: String,
) -> Result<crate::api::data::DTODataTable, String> {
    if count == 0 || count > 100 {
        return Err("column count must be 1..=100".to_string());
    }
    let role = parse_engine_role(&role)?;
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    let rows = table.row_count();
    let base = table.columns.len();
    for i in 0..count {
        table.add_column(EngineDataColumn {
            name: format!("Col {}", base + i + 1),
            role: role.clone(),
            data: vec![f64::NAN; rows],
        });
    }
    Ok(table.clone().into())
}

/// Appends `count` blank (NaN) rows to every column.
#[flutter_rust_bridge::frb(sync)]
pub fn add_rows(
    table_id: String,
    count: usize,
) -> Result<crate::api::data::DTODataTable, String> {
    if count == 0 || count > 100_000 {
        return Err("row count must be 1..=100000".to_string());
    }
    let mut store = lock_or_recover(get_table_store());
    let table = store.get_mut(&table_id).ok_or_else(|| table_not_found(&table_id))?;
    if table.row_count().saturating_add(count) > 1_000_000 {
        return Err("table would exceed 1000000 rows".to_string());
    }
    table.add_rows(count);
    Ok(table.clone().into())
}

fn id_prefix(node_type: &EngineNodeType) -> &'static str {
    match node_type {
        EngineNodeType::Folder => "folder",
        EngineNodeType::Dataset => "table",
        EngineNodeType::Plot => "graph",
        EngineNodeType::Function => "function",
        EngineNodeType::Shape => "shape",
    }
}

/// Deep-copies a node subtree beside the original with fresh IDs —
/// tables and all property entries included. The top copy is suffixed
/// with `" copy"` and its DTO tree is returned.
#[flutter_rust_bridge::frb(sync)]
pub fn duplicate_node(node_id: String) -> Result<ProjectNode, String> {
    if node_id == "root_1" {
        return Err("cannot duplicate the workspace root".to_string());
    }
    let mut state = lock_or_recover(get_state());

    // Locate the parent by id (recursive, lock-free walk).
    fn find_parent_id(node: &EngineProjectNode, target: &str) -> Option<String> {
        for c in &node.children {
            if c.id == target {
                return Some(node.id.clone());
            }
            if let Some(p) = find_parent_id(c, target) {
                return Some(p);
            }
        }
        None
    }
    let parent_id =
        find_parent_id(&state, &node_id).ok_or_else(|| format!("node '{node_id}' not found"))?;

    // Snapshot the stores we need to copy from (released before writing).
    let tables = snapshot_tables_engine();
    let folder_props = crate::api::properties::snapshot_folder_props();
    let graph_props = crate::api::properties::snapshot_graph_props();
    let table_props = crate::api::properties::snapshot_table_props();
    let function_props = crate::api::properties::snapshot_function_props();
    let shape_props = crate::api::properties::snapshot_shape_props();

    // Clone the subtree with fresh IDs, collecting (old, new) pairs.
    fn clone_subtree(
        node: &EngineProjectNode,
        pairs: &mut Vec<(String, String)>,
        top: bool,
    ) -> EngineProjectNode {
        let new_id = generate_id(id_prefix(&node.node_type));
        pairs.push((node.id.clone(), new_id.clone()));
        let new_name = if top {
            format!("{} copy", node.name)
        } else {
            node.name.clone()
        };
        let mut out = EngineProjectNode::new(&new_id, &new_name, node.node_type.clone());
        for c in &node.children {
            out.add_child(clone_subtree(c, pairs, false));
        }
        out
    }
    // Splice the clone in right after the original.
    fn splice_clone(
        node: &mut EngineProjectNode,
        parent_id: &str,
        target: &str,
        pairs: &mut Vec<(String, String)>,
    ) -> bool {
        if node.id == parent_id {
            if let Some(pos) = node.children.iter().position(|c| c.id == target) {
                let cloned = clone_subtree(&node.children[pos], pairs, true);
                node.children.insert(pos + 1, cloned);
                return true;
            }
            return false;
        }
        for c in &mut node.children {
            if splice_clone(c, parent_id, target, pairs) {
                return true;
            }
        }
        false
    }
    let mut pairs: Vec<(String, String)> = Vec::new();
    if !splice_clone(&mut state, &parent_id, &node_id, &mut pairs) {
        return Err(format!("node '{node_id}' not found"));
    }

    // Deep-copy tables + property entries under the new IDs.
    {
        let mut store = lock_or_recover(get_table_store());
        for (old, new) in &pairs {
            if let Some(t) = tables.get(old) {
                let mut copy = t.clone();
                copy.id = new.clone();
                store.insert(new.clone(), copy);
            }
        }
    }
    for (old, new) in &pairs {
        if let Some(p) = folder_props.get(old) {
            crate::api::properties::restore_single_folder(new.clone(), p.clone());
        }
        if let Some(p) = graph_props.get(old) {
            crate::api::properties::restore_single_graph(new.clone(), p.clone());
        }
        if let Some(p) = table_props.get(old) {
            crate::api::properties::restore_single_table(new.clone(), p.clone());
        }
        if let Some(p) = function_props.get(old) {
            crate::api::properties::restore_single_function(new.clone(), p.clone());
        }
        if let Some(p) = shape_props.get(old) {
            crate::api::properties::restore_single_shape(new.clone(), p.clone());
        }
    }

    Ok(state.clone().into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn add_empty_table(parent_id: String, name: String, row_count: usize, col_count: usize) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    let new_id = generate_id("table");

    let mut et = EngineDataTable::new(&new_id, &name);
    for i in 0..col_count {
        let (col_name, role) = if i == 0 {
            ("Position".to_string(), EngineColumnRole::X)
        } else {
            (format!("Col {}", i + 1), EngineColumnRole::Y)
        };
        et.add_column(EngineDataColumn {
            name: col_name,
            role,
            data: vec![f64::NAN; row_count],
        });
    }

    let mut store = lock_or_recover(get_table_store());
    store.insert(new_id.clone(), et);

    let new_node = EngineProjectNode::new(&new_id, &name, EngineNodeType::Dataset);
    let mut opt_node = Some(new_node);
    state.insert_node_opt(&parent_id, &mut opt_node);
    if let Some(node) = opt_node.take() {
        state.add_child(node);
    }

    drop(store);
    let ds = dataset_ids_in_order(&state, &parent_id);
    let fs = function_ids_in_order(&state, &parent_id);
    let color =
        crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
    crate::api::palettes::init_curve_props(&new_id, &name, color);

    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn add_table_from_raw(parent_id: String, raw: String, display_name: String) -> ProjectNode {
    let mut state = lock_or_recover(get_state());
    // Parse using existing parser
    let mut dto = crate::api::data::parse_clipboard_table(raw);
    // assign unique id and display name
    let new_id = generate_id("table");
    dto.id = new_id.clone();
    dto.name = display_name.clone();

    // store engine table
    let engine_table = dto_to_engine_table(dto.clone());
    let mut store = lock_or_recover(get_table_store());
    store.insert(new_id.clone(), engine_table);

    // insert project node
    let new_node = EngineProjectNode::new(&new_id, &display_name, EngineNodeType::Dataset);
    let mut opt_node = Some(new_node);
    state.insert_node_opt(&parent_id, &mut opt_node);
    if let Some(node) = opt_node.take() {
        state.add_child(node);
    }

    drop(store);
    let ds = dataset_ids_in_order(&state, &parent_id);
    let fs = function_ids_in_order(&state, &parent_id);
    let color =
        crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
    crate::api::palettes::init_curve_props(&new_id, &display_name, color);

    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_table(table_id: String) -> crate::api::data::DTODataTable {
    let store = lock_or_recover(get_table_store());
    if let Some(t) = store.get(&table_id) {
        t.clone().into()
    } else {
        crate::api::data::get_empty_table_data()
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_tables_for_graph(graph_id: String) -> Vec<crate::api::data::DTODataTable> {
    let state = lock_or_recover(get_state());
    let mut result = Vec::new();
    // find graph node
    fn find(node: &EngineProjectNode, target: &str, out: &mut Vec<String>) {
        if node.id == target {
            for c in &node.children {
                match c.node_type {
                    EngineNodeType::Dataset => out.push(c.id.clone()),
                    _ => (),
                }
            }
            return;
        }
        for c in &node.children {
            find(c, target, out);
        }
    }
    let mut ids = Vec::new();
    find(&state, &graph_id, &mut ids);

    let store = lock_or_recover(get_table_store());
    for id in ids {
        if let Some(t) = store.get(&id) {
            result.push(t.clone().into());
        }
    }
    result
}

// ---------------------------------------------------------------------------
// Persistence helpers (crate-internal): snapshot / restore project + tables.
// Used by `persistence.rs` to pack/unpack the `.primeplot` bundle.
// ---------------------------------------------------------------------------

/// Dataset children of `graph_id` in tree order (empty when the node is
/// missing or not a plot). Used for palette cycling / re-alignment.
/// Callers must NOT hold any store lock other than `PROJECT_STATE`
/// (palette code locks the property stores).
pub(crate) fn dataset_ids_in_order(
    state: &EngineProjectNode,
    graph_id: &str,
) -> Option<Vec<String>> {
    child_ids_of_type(state, graph_id, true)
}

/// Function children of `graph_id` in tree order. Same locking rules.
pub(crate) fn function_ids_in_order(
    state: &EngineProjectNode,
    graph_id: &str,
) -> Option<Vec<String>> {
    child_ids_of_type(state, graph_id, false)
}

fn child_ids_of_type(
    state: &EngineProjectNode,
    graph_id: &str,
    datasets: bool,
) -> Option<Vec<String>> {
    fn find<'a>(node: &'a EngineProjectNode, target: &str) -> Option<&'a EngineProjectNode> {
        if node.id == target {
            return Some(node);
        }
        for c in &node.children {
            if let Some(n) = find(c, target) {
                return Some(n);
            }
        }
        None
    }
    let graph = find(state, graph_id)?;
    if !matches!(graph.node_type, EngineNodeType::Plot) {
        return None;
    }
    Some(
        graph
            .children
            .iter()
            .filter(|c| match c.node_type {
                EngineNodeType::Dataset => datasets,
                EngineNodeType::Function => !datasets,
                _ => false,
            })
            .map(|c| c.id.clone())
            .collect(),
    )
}

pub(crate) fn snapshot_tree_engine() -> EngineProjectNode {
    lock_or_recover(get_state()).clone()
}

pub(crate) fn restore_tree_engine(tree: EngineProjectNode) {
    *lock_or_recover(get_state()) = tree;
}

pub(crate) fn snapshot_tables_engine() -> HashMap<String, EngineDataTable> {
    lock_or_recover(get_table_store()).clone()
}

pub(crate) fn restore_tables_engine(map: HashMap<String, EngineDataTable>) {
    *lock_or_recover(get_table_store()) = map;
}

/// Builds the canonical empty project: Workspace > Project > Graph > Table.
pub(crate) fn default_project_tree_engine() -> EngineProjectNode {
    let mut root = EngineProjectNode::new("root_1", "Workspace", EngineNodeType::Folder);
    let mut project = EngineProjectNode::new("project_1", "Project", EngineNodeType::Folder);
    let mut graph = EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
    graph.add_child(EngineProjectNode::new(
        "table_1",
        "Table",
        EngineNodeType::Dataset,
    ));
    project.add_child(graph);
    root.add_child(project);
    root
}

/// After loading a bundle, bump NEXT_ID past the highest numeric suffix found
/// in the tree so newly created nodes never collide with restored IDs.
pub(crate) fn reset_next_id_from_tree(tree: &EngineProjectNode) {
    fn max_suffix(node: &EngineProjectNode, current: usize) -> usize {
        let mut best = current;
        if let Some(pos) = node.id.rfind('_') {
            if let Ok(n) = node.id[pos + 1..].parse::<usize>() {
                if n >= best {
                    best = n;
                }
            }
        }
        for child in &node.children {
            best = max_suffix(child, best);
        }
        best
    }
    let max_found = max_suffix(tree, 100);
    let desired = max_found.saturating_add(1);
    // Only move forward, never backwards (avoids reusing live IDs).
    let current = NEXT_ID.load(Ordering::SeqCst);
    if desired > current {
        NEXT_ID.store(desired, Ordering::SeqCst);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use data_engine::table::DataColumn;

    fn seed_table() {
        let mut t = EngineDataTable::new("coltest_1", "Cols");
        t.add_column(DataColumn {
            name: "X".to_string(),
            role: EngineColumnRole::X,
            data: vec![1.0, 2.0],
        });
        t.add_column(DataColumn {
            name: "Y".to_string(),
            role: EngineColumnRole::Y,
            data: vec![3.0, 4.0],
        });
        get_table_store()
            .lock()
            .unwrap()
            .insert("coltest_1".to_string(), t);
    }

    #[test]
    fn column_endpoints_round_trip() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved = snapshot_tables_engine();
        seed_table();

        // add (blank, NaN-filled to row count)
        let t = add_column(
            "coltest_1".to_string(),
            "Err".to_string(),
            "YError".to_string(),
        )
        .unwrap();
        assert_eq!(t.columns.len(), 3);
        assert!(add_column("coltest_1".to_string(), "  ".to_string(), "Y".to_string()).is_err());
        assert!(add_column("coltest_1".to_string(), "Z".to_string(), "Bogus".to_string()).is_err());

        // rename + role
        let t = rename_column("coltest_1".to_string(), 2, "E".to_string()).unwrap();
        assert_eq!(t.columns[2].name, "E");
        assert!(rename_column("coltest_1".to_string(), 9, "Z".to_string()).is_err());
        let t = set_column_role("coltest_1".to_string(), 2, "Text".to_string()).unwrap();
        assert!(matches!(
            t.columns[2].role,
            crate::api::data::DTOColumnRole::Text
        ));

        // reorder
        let t = reorder_column("coltest_1".to_string(), 0, 2).unwrap();
        assert_eq!(t.columns[0].name, "Y");

        // remove guards the last X / Y
        assert!(remove_column("coltest_1".to_string(), 0).is_err()); // last Y
        assert!(remove_column("coltest_1".to_string(), 9).is_err()); // OOB
        assert!(remove_column("coltest_1".to_string(), 2).is_err()); // last X
        let t = remove_column("coltest_1".to_string(), 1).unwrap(); // Text col
        assert_eq!(t.columns.len(), 2);

        // unknown table is a clean error
        assert!(lock_or_recover(get_table_store()).get("nope").is_none());
        assert!(add_column("nope".to_string(), "A".to_string(), "X".to_string()).is_err());

        restore_tables_engine(saved);
    }

    #[test]
    fn recovers_from_poisoned_state_lock() {
        use std::panic::AssertUnwindSafe;

        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        // Deliberately poison PROJECT_STATE.
        let _ = std::panic::catch_unwind(AssertUnwindSafe(|| {
            let _guard = get_state().lock().unwrap();
            panic!("deliberate poison for recovery test");
        }));
        // Subsequent FFI calls must succeed via lock recovery.
        let tree = get_project_tree();
        assert!(!tree.id.is_empty());
        // And writes work too.
        let renamed =
            rename_project_node("root_1".to_string(), "Workspace".to_string());
        assert_eq!(renamed.name, "Workspace");
    }
}

#[cfg(test)]
mod dup_tests {
    use super::*;
    use data_engine::table::DataColumn;

    fn seed_tree() {
        let mut root = EngineProjectNode::new("root_1", "W", EngineNodeType::Folder);
        let mut graph = EngineProjectNode::new("dup_g", "G", EngineNodeType::Plot);
        graph.add_child(EngineProjectNode::new("dup_t", "Curve", EngineNodeType::Dataset));
        root.add_child(graph);
        restore_tree_engine(root);
        let mut t = EngineDataTable::new("dup_t", "Curve");
        t.add_column(DataColumn {
            name: "X".to_string(),
            role: EngineColumnRole::X,
            data: vec![1.0, 2.0],
        });
        lock_or_recover(get_table_store()).insert("dup_t".to_string(), t);
        crate::api::properties::set_table_properties(
            "dup_t".to_string(),
            crate::api::properties::TableProperties {
                legend_display_name: "Curve".to_string(),
                line_color: "#FF7F0E".to_string(),
                ..Default::default()
            },
        );
    }

    #[test]
    fn duplicate_copies_deeply() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved_tree = snapshot_tree_engine();
        let saved_tables = snapshot_tables_engine();
        let saved_tprops = crate::api::properties::snapshot_table_props();
        seed_tree();

        assert!(duplicate_node("root_1".to_string()).is_err());
        assert!(duplicate_node("missing".to_string()).is_err());

        // Duplicate a table: new id, " copy" name, same data + props.
        let tree = duplicate_node("dup_t".to_string()).unwrap();
        let graph = tree
            .children
            .iter()
            .find(|n| matches!(n.node_type, NodeType::Plot))
            .unwrap();
        assert_eq!(graph.children.len(), 2);
        let copy = &graph.children[1];
        assert_ne!(copy.id, "dup_t");
        assert_eq!(copy.name, "Curve copy");
        let store = lock_or_recover(get_table_store());
        assert_eq!(store[&copy.id].columns[0].data, vec![1.0, 2.0]);
        drop(store);
        assert_eq!(
            crate::api::properties::get_table_properties(copy.id.clone()).line_color,
            "#FF7F0E"
        );

        // Duplicate the graph: it lands beside the original with fresh ids.
        let tree2 = duplicate_node("dup_g".to_string()).unwrap();
        assert_eq!(tree2.children.len(), 2);
        let graph_copy = &tree2.children[1];
        assert_eq!(graph_copy.name, "G copy");
        assert_ne!(graph_copy.id, "dup_g");
        assert_eq!(graph_copy.children.len(), 2);
        assert_ne!(graph_copy.children[0].id, "dup_t");

        // Mutating the copy leaves the original alone.
        rename_column(copy.id.clone(), 0, "Changed".to_string()).unwrap();
        assert_eq!(
            lock_or_recover(get_table_store())["dup_t"].columns[0].name,
            "X"
        );

        restore_tree_engine(saved_tree);
        restore_tables_engine(saved_tables);
        crate::api::properties::restore_table_props(saved_tprops);
    }
}
